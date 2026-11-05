"""Makes every sound and song in Snowed In from scratch.

Each one is synthesised here from sine waves and noise, so the project owns
all of it outright: no samples, no loops from a library, and every tune was
written for this game (none is a cover or soundalike of an existing song).
Run it from games/snowed-in with Python 3 and numpy, with ffmpeg on the path
for OGG encoding:

    python3 tools/make_sounds.py

It writes assets/audio/<snake_case name>.ogg, one per entry in
src/shared/Config/Sounds.luau (MusicDay -> music_day.ogg). Upload them to
Roblox and paste their asset ids into that file (docs/launch.md has the
steps).
"""

import os
import re
import subprocess
import sys

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "audio")
rng = np.random.default_rng(1225)


# Building blocks -------------------------------------------------------------


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def reseed(seed):
    """Gives each sound its own random numbers, so changing one sound
    doesn't change the others."""
    global rng
    rng = np.random.default_rng(seed)


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def note(name):
    """Frequency of a note name such as "D5", "Bb3" or "F#4"."""
    semitone = STEPS[name[0]]
    rest = name[1:]
    if rest.startswith("b"):
        semitone -= 1
        rest = rest[1:]
    elif rest.startswith("#"):
        semitone += 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + semitone
    return 440.0 * 2 ** ((midi - 69) / 12)


def band(signal, low, high):
    """Keeps only frequencies between low and high, with soft edges."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    gain = 1 / (1 + (low / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * gain, len(signal))


def sweep(signal, start, end, width=0.5):
    """A band of noise whose centre slides from start to end."""
    out = np.zeros_like(signal)
    block = 1024
    count = int(np.ceil(len(signal) / block))
    for i in range(count):
        centre = start * (end / start) ** (i / max(count - 1, 1))
        piece = signal[i * block : (i + 1) * block]
        out[i * block : i * block + len(piece)] = band(piece, centre * (1 - width), centre * (1 + width))
    return out


def envelope(seconds, attack=0.005, decay=6.0):
    t = times(seconds)
    return np.minimum(1, t / attack) * np.exp(-t * decay)


def tone(freq, seconds, amp=1.0, decay=4.0, partials=((1, 1.0),), attack=0.004):
    t = times(seconds)
    out = sum(level * np.sin(2 * np.pi * freq * ratio * t) for ratio, level in partials)
    return amp * out * envelope(seconds, attack, decay)


def glide(start, end, seconds, amp=1.0, decay=3.0, harmonics=(1,)):
    """A tone that slides from one pitch to another."""
    t = times(seconds)
    freq = start * (end / start) ** (t / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    out = sum(np.sin(h * phase) / h for h in harmonics)
    return amp * out * envelope(seconds, 0.01, decay)


def bell(freq, seconds=2.0, amp=1.0):
    """A glockenspiel or sleigh-bell like tine."""
    partials = [(1, 1.0, 2.5), (2.76, 0.4, 6), (5.4, 0.18, 10), (8.93, 0.07, 16)]
    t = times(seconds)
    out = sum(level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * d) for ratio, level, d in partials)
    return amp * out * np.minimum(1, t / 0.002)


def pluck(freq, seconds=0.8, amp=1.0, bright=6):
    """A plucked string, a little like a mandolin or a guitar."""
    t = times(seconds)
    out = sum(np.sin(2 * np.pi * freq * n * t) * np.exp(-t * (3 + n * 1.6)) / n for n in range(1, bright + 1))
    return amp * out * np.minimum(1, t / 0.002)


def pad(freq, seconds, amp=1.0, attack=0.4, release=0.6, wobble=0.004):
    """A soft, warm drone that swells in and out."""
    t = times(seconds)
    vibrato = 1 + wobble * np.sin(2 * np.pi * 4.5 * t)
    phase = 2 * np.pi * freq * np.cumsum(vibrato) / RATE
    out = np.sin(phase) + 0.4 * np.sin(2 * phase) + 0.15 * np.sin(3 * phase)
    shape = np.minimum(1, t / attack) * np.clip((seconds - t) / release, 0, 1)
    return amp * out * shape


def saw(freq, seconds, amp=1.0, cutoff=900, decay=3.0):
    t = times(seconds)
    out = np.zeros_like(t)
    harmonic = 1
    while freq * harmonic < 7000:
        out += np.sin(2 * np.pi * freq * harmonic * t) / harmonic / (1 + (freq * harmonic / cutoff) ** 2)
        harmonic += 1
    shape = np.minimum(1, t / 0.005) * (0.5 + 0.5 * np.exp(-t * decay)) * np.clip((seconds - t) / 0.04, 0, 1)
    return amp * out * shape


def square(freq, seconds, amp=1.0):
    t = times(seconds)
    wobble = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / RATE
    out = sum(np.sin(n * phase) / n for n in (1, 3, 5, 7, 9))
    shape = np.minimum(1, t / 0.01) * (0.7 + 0.3 * np.exp(-t * 5)) * np.clip((seconds - t) / 0.05, 0, 1)
    return amp * out * shape


def thud(seconds=0.5, amp=1.0, start=110, end=42, decay=7):
    t = times(seconds)
    freq = end + (start - end) * np.exp(-t * 14)
    return amp * np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * decay) * np.minimum(1, t / 0.002)


def kick(amp=1.0):
    t = times(0.4)
    freq = 46 + 110 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 8)
    return amp * body * np.minimum(1, t / 0.001)


def snare(amp=1.0):
    t = times(0.28)
    return amp * (np.sin(2 * np.pi * 190 * t) * np.exp(-t * 30) * 0.5 + band(noise(0.28), 1200, 9000) * np.exp(-t * 17))


def hat(amp=1.0, length=0.07):
    t = times(length)
    return amp * band(noise(length), 7000, 16000) * np.exp(-t * (3 / length))


def jingle(amp=1.0):
    """A shake of sleigh bells: a cluster of tiny bright tines."""
    out = np.zeros(int(0.35 * RATE))
    for k in range(6):
        start = int(rng.uniform(0, 0.05) * RATE)
        ring = bell(rng.uniform(2400, 4200), 0.3, 0.25)
        out[start : start + len(ring)] += ring[: len(out) - start]
    return amp * (out + band(noise(0.35), 6000, 14000) * np.exp(-times(0.35) * 14) * 0.25)


def crackle(seconds, amp=1.0, density=60):
    """Fire crackles: random tiny pops."""
    out = np.zeros(int(seconds * RATE))
    for _ in range(int(seconds * density)):
        at = int(rng.uniform(0, seconds - 0.02) * RATE)
        pop = band(noise(0.015), 1500, 9000) * np.exp(-times(0.015) * 300) * rng.uniform(0.2, 1)
        out[at : at + len(pop)] += pop
    return amp * out


def place(track, sound, at, pan=0.0):
    """Adds a mono sound to a stereo track at a time, panned -1 to 1."""
    start = int(at * RATE)
    if start >= track.shape[1]:
        return
    end = min(track.shape[1], start + len(sound))
    piece = sound[: end - start]
    track[0, start:end] += piece * np.sqrt((1 - pan) / 2) * 1.414
    track[1, start:end] += piece * np.sqrt((1 + pan) / 2) * 1.414


def fold(track, seconds):
    """Folds everything past the loop point back onto the start, so the
    loop joins without a click."""
    samples = int(seconds * RATE)
    out = track[:, :samples].copy()
    tail = track[:, samples:]
    out[:, : tail.shape[1]] += tail[:, :samples]
    return out


def reverb(signal, seconds=1.8, wet=0.25, seed=0):
    """A snowy hall: convolves with a burst of decaying noise."""
    local = np.random.default_rng(seed)
    t = times(seconds)
    impulse = band(local.standard_normal(len(t)) * np.exp(-t * 3.5), 150, 6000)
    impulse /= np.sqrt(np.sum(impulse**2))
    size = len(signal) + len(impulse)
    wet_signal = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)
    dry = np.concatenate([signal, np.zeros(len(impulse))])
    return dry * (1 - wet) + wet_signal * wet * 2.5


def trim(signal, floor=0.0015):
    """Cuts the silent tail."""
    loud = np.nonzero(np.abs(signal) > floor * np.max(np.abs(signal)))[0]
    return signal[: loud[-1] + 1] if len(loud) else signal


def normalise(signal, peak=0.89):
    biggest = np.max(np.abs(signal))
    return signal * (peak / biggest if biggest > 0 else 1)


def snake(name):
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def write(name, signal):
    """Writes a sound (mono 1-D, or stereo 2 x N) as assets/audio/<name>.ogg."""
    os.makedirs(OUT, exist_ok=True)
    data = np.asarray(signal, dtype=np.float32)
    channels = 1 if data.ndim == 1 else data.shape[0]
    frames = data[:, None] if data.ndim == 1 else data.T
    path = os.path.join(OUT, f"{snake(name)}.ogg")
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "f32le", "-ar", str(RATE), "-ac", str(channels), "-i", "pipe:",
            "-c:a", "libvorbis", "-q:a", "4", path,
        ],
        input=np.ascontiguousarray(frames).tobytes(),
        check=True,
    )
    print(f"wrote {path} ({os.path.getsize(path) // 1024} KB)")


def sfx(name, signal, peak=0.89, room=0.0):
    signal = np.asarray(signal, dtype=np.float64)
    if room > 0:
        signal = reverb(signal, 1.2, room)
    write(name, normalise(trim(signal), peak))


def mix(*sounds):
    """Adds sounds of different lengths together."""
    length = max(len(s) for s in sounds)
    out = np.zeros(length)
    for s in sounds:
        out[: len(s)] += s
    return out


def after(seconds, sound):
    """Pads the front of a sound with silence."""
    return np.concatenate([np.zeros(int(seconds * RATE)), sound])


# Music -----------------------------------------------------------------------
# Three original tunes. Each is 16 bars that loop seamlessly.

CHORDS = {
    "D": ("D", "F#", "A"),
    "G": ("G", "B", "D"),
    "A": ("A", "C#", "E"),
    "Bm": ("B", "D", "F#"),
    "Em": ("E", "G", "B"),
    "Dm": ("D", "F", "A"),
    "Gm": ("G", "Bb", "D"),
    "Bb": ("Bb", "D", "F"),
    "C": ("C", "E", "G"),
    "F": ("F", "A", "C"),
    "Am": ("A", "C", "E"),
    "B": ("B", "D#", "F#"),
}


def chord_notes(chord, octave):
    return [note(f"{n}{octave}") for n in CHORDS[chord]]


def melody(track, start, beat, phrase, voice, amp, pan=0.0):
    """Plays a list of (note or None, beats) from start."""
    at = start
    for name, beats in phrase:
        if name:
            place(track, voice(note(name), beats * beat, amp), at, pan)
        at += beats * beat


def music_day():
    """Hearthside: a cosy D major tune at 96 bpm for the days, on a
    glockenspiel over plucked strings, sleigh bells and a soft bass."""
    reseed(10)
    bpm, bars = 96, 16
    beat = 60 / bpm
    length = bars * 4 * beat
    track = np.zeros((2, int((length + 4) * RATE)))
    progression = ["D", "G", "Bm", "A"] * 2 + ["G", "D", "Em", "A"] + ["D", "G", "A", "D"]
    for bar, chord in enumerate(progression):
        start = bar * 4 * beat
        low = chord_notes(chord, 3)
        for k, f in enumerate(low + [low[0] * 2, low[1] * 2, low[0] * 2, low[2], low[1]]):
            place(track, pluck(f, beat * 1.4, 0.16), start + k * beat / 2, -0.4 if k % 2 else 0.3)
        place(track, saw(low[0] / 2, beat * 1.8, 0.22, cutoff=300), start)
        place(track, saw(low[2] / 2, beat * 1.8, 0.18, cutoff=300), start + 2 * beat)
        for f in chord_notes(chord, 4):
            place(track, pad(f, 4 * beat + 0.3, 0.035, attack=0.6, release=0.6), start, 0.0)
        for eighth in range(8):
            if eighth % 2 == 1 or bar >= 4:
                place(track, jingle(0.12 if eighth % 2 else 0.07), start + eighth * beat / 2, 0.5)
        if bar >= 4:
            place(track, kick(0.35), start)
            place(track, kick(0.25), start + 2 * beat)
    tune = [
        [("F#5", 1), ("A5", 1), ("B5", 1), ("A5", 1)],
        [("G5", 1.5), ("F#5", 0.5), ("E5", 1), ("D5", 1)],
        [("F#5", 1), ("D5", 1), ("B4", 1), ("D5", 1)],
        [("E5", 3), (None, 1)],
        [("F#5", 1), ("A5", 1), ("D6", 1), ("C#6", 1)],
        [("B5", 1.5), ("A5", 0.5), ("G5", 1), ("B5", 1)],
        [("A5", 1), ("F#5", 1), ("D5", 1), ("F#5", 1)],
        [("E5", 2), ("A4", 1), (None, 1)],
        [("B4", 1), ("D5", 1), ("G5", 1.5), ("F#5", 0.5)],
        [("F#5", 1), ("E5", 1), ("D5", 2)],
        [("G5", 1), ("F#5", 1), ("E5", 1), ("B4", 1)],
        [("C#5", 2), ("E5", 1), ("A5", 1)],
        [("F#5", 1), ("A5", 1), ("B5", 1), ("D6", 1)],
        [("B5", 1), ("G5", 1), ("B5", 1), ("D6", 1)],
        [("C#6", 1.5), ("B5", 0.5), ("A5", 1), ("E5", 1)],
        [("D5", 3), (None, 1)],
    ]
    for bar, phrase in enumerate(tune):
        melody(track, bar * 4 * beat, beat, phrase, lambda f, s, a: bell(f, max(s, 0.9) + 0.6, a), 0.3, 0.1)
    out = fold(track, length)
    out = np.stack([reverb(out[0], 2.2, 0.28, 1)[: out.shape[1]], reverb(out[1], 2.2, 0.28, 2)[: out.shape[1]]])
    write("MusicDay", normalise(out, 0.85))


def music_night():
    """Long Night: a tense D minor tune at 112 bpm, with pulsing strings, a
    heartbeat kick, ticking hats and a glassy tune, spooky but never scary."""
    reseed(11)
    bpm, bars = 112, 16
    beat = 60 / bpm
    length = bars * 4 * beat
    track = np.zeros((2, int((length + 4) * RATE)))
    progression = ["Dm", "Bb", "Gm", "A"] * 3 + ["Dm", "Gm", "Bb", "A"]
    for bar, chord in enumerate(progression):
        start = bar * 4 * beat
        low = chord_notes(chord, 3)
        for eighth in range(8):
            place(track, saw(low[0] / 2, beat * 0.42, 0.2, cutoff=420, decay=8), start + eighth * beat / 2)
        for f in low:
            place(track, pad(f, 4 * beat + 0.2, 0.05, attack=0.15, release=0.3, wobble=0.008), start, -0.3)
        place(track, thud(0.4, 0.5, 90, 40), start)
        place(track, thud(0.4, 0.35, 90, 40), start + 0.35)
        place(track, thud(0.4, 0.5, 90, 40), start + 2 * beat)
        place(track, thud(0.4, 0.35, 90, 40), start + 2 * beat + 0.35)
        for sixteenth in range(16):
            place(track, hat(0.06 if sixteenth % 4 else 0.12), start + sixteenth * beat / 4, 0.4)
        if bar % 4 == 3:
            for h in range(8):
                place(track, snare(0.05 + h * 0.03), start + 2 * beat + h * beat / 4, -0.1)
    tune = [
        [("A5", 2), ("F5", 1), ("D5", 1)],
        [("F5", 2), ("D5", 2)],
        [("G5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1)],
        [("E5", 4)],
        [("A5", 1), ("C6", 1), ("A5", 1), ("F5", 1)],
        [("Bb5", 2), ("F5", 2)],
        [("D6", 1), ("C6", 1), ("Bb5", 1), ("G5", 1)],
        [("A5", 3), (None, 1)],
        [("D6", 2), ("A5", 1), ("F5", 1)],
        [("F5", 1), ("G5", 1), ("A5", 2)],
        [("Bb5", 1), ("A5", 1), ("G5", 1), ("D5", 1)],
        [("C#5", 4)],
        [("D5", 1), ("F5", 1), ("A5", 1), ("D6", 1)],
        [("Bb5", 2), ("G5", 2)],
        [("F5", 1), ("Bb5", 1), ("D6", 1), ("Bb5", 1)],
        [("A5", 2), ("E5", 2)],
    ]
    for bar, phrase in enumerate(tune):
        melody(
            track,
            bar * 4 * beat,
            beat,
            phrase,
            lambda f, s, a: tone(f, s + 0.4, a, decay=1.6, partials=((1, 1), (2, 0.3), (4.1, 0.1))),
            0.18,
            0.15,
        )
    out = fold(track, length)
    out = np.stack([reverb(out[0], 2.5, 0.3, 3)[: out.shape[1]], reverb(out[1], 2.5, 0.3, 4)[: out.shape[1]]])
    write("MusicNight", normalise(out, 0.85))


def music_boss():
    """Yeti Stomp: a driving E minor tune at 138 bpm for when a yeti comes,
    with a big kick, a growling bass and an arcade lead."""
    reseed(12)
    bpm, bars = 138, 16
    beat = 60 / bpm
    length = bars * 4 * beat
    track = np.zeros((2, int((length + 4) * RATE)))
    progression = ["Em", "C", "D", "B"] * 4
    for bar, chord in enumerate(progression):
        start = bar * 4 * beat
        low = chord_notes(chord, 2)
        for b in range(4):
            place(track, kick(0.8), start + b * beat)
        for b in (1, 3):
            place(track, snare(0.5), start + b * beat, 0.05)
        for eighth in range(8):
            place(track, hat(0.12), start + eighth * beat / 2 + beat / 4, 0.4)
            place(track, saw(low[0], beat * 0.45, 0.25, cutoff=600, decay=6), start + eighth * beat / 2)
        for f in chord_notes(chord, 4):
            place(track, pad(f, 4 * beat, 0.03, attack=0.05, release=0.2), start, -0.4)
    riff = [("E5", 0.5), ("G5", 0.5), ("B5", 1), ("A5", 0.5), ("G5", 0.5), ("F#5", 1)]
    tune = [
        riff,
        [("E5", 1), ("C5", 1), ("E5", 1), ("G5", 1)],
        [("F#5", 0.5), ("A5", 0.5), ("D6", 1), ("C6", 0.5), ("A5", 0.5), ("F#5", 1)],
        [("D#5", 2), ("F#5", 2)],
    ] * 2 + [
        [("B5", 1.5), ("A5", 0.5), ("G5", 1), ("E5", 1)],
        [("G5", 1), ("C6", 1), ("B5", 1), ("G5", 1)],
        [("A5", 1.5), ("G5", 0.5), ("F#5", 1), ("D5", 1)],
        [("D#5", 1), ("F#5", 1), ("B5", 2)],
    ] * 2
    for bar, phrase in enumerate(tune):
        melody(track, bar * 4 * beat, beat, phrase, lambda f, s, a: square(f, s * 0.9, a), 0.14, 0.1)
    out = fold(track, length)
    out = np.stack([reverb(out[0], 1.5, 0.2, 5)[: out.shape[1]], reverb(out[1], 1.5, 0.2, 6)[: out.shape[1]]])
    write("MusicBoss", normalise(out, 0.85))


def wind():
    """The blizzard: gusts of shaped noise, a whistle now and then, as a
    30 second loop."""
    reseed(13)
    seconds = 30
    out = np.zeros((2, int((seconds + 3) * RATE)))
    for side in range(2):
        base = noise(seconds + 3)
        gust = np.interp(
            np.arange(len(base)),
            np.linspace(0, len(base), 16),
            rng.uniform(0.25, 1.0, 16),
        )
        low = band(base, 120, 900) * gust
        high = band(noise(seconds + 3), 1500, 4000) * gust**2 * 0.3
        out[side] += low + high
    for k in range(5):
        start = rng.uniform(0, seconds - 4)
        whistle = glide(rng.uniform(700, 900), rng.uniform(500, 650), 3.5, 0.06, decay=0.6)
        place(out, whistle, start, rng.uniform(-0.8, 0.8))
    write("Wind", normalise(fold(out, seconds), 0.7))


# Effects ---------------------------------------------------------------------


def make_effects():
    reseed(20)
    t = times
    # Gathering.
    sfx("Chop", mix(thud(0.35, 1.0, 220, 120, 14), band(noise(0.2), 300, 2500) * np.exp(-t(0.2) * 30) * 0.8), room=0.15)
    sfx(
        "Mine",
        mix(
            tone(1850, 0.5, 0.6, decay=9, partials=((1, 1), (2.4, 0.5), (4.1, 0.3))),
            band(noise(0.12), 2000, 9000) * np.exp(-t(0.12) * 40) * 0.6,
            thud(0.2, 0.5, 160, 90, 20),
        ),
        room=0.2,
    )
    crunch = np.zeros(int(0.4 * RATE))
    for k in range(5):
        piece = band(noise(0.06), 600, 5000) * np.exp(-t(0.06) * 50) * rng.uniform(0.5, 1)
        at = int(k * 0.06 * RATE)
        crunch[at : at + len(piece)] += piece
    sfx("Dig", mix(crunch, thud(0.3, 0.4, 140, 80, 16)))
    sfx("Splash", mix(sweep(noise(0.6), 3000, 500) * np.exp(-t(0.6) * 6), tone(520, 0.3, 0.2, decay=12)))
    sfx("Pick", mix(tone(880, 0.15, 0.6, decay=25), after(0.05, tone(1320, 0.2, 0.5, decay=20)), band(noise(0.15), 2000, 7000) * np.exp(-t(0.15) * 30) * 0.3))
    sfx("Deposit", mix(thud(0.3, 0.9, 180, 90, 12), after(0.08, jingle(0.8)), after(0.12, tone(660, 0.4, 0.3, decay=8))))
    sfx("Crate", mix(band(noise(0.15), 400, 3000) * np.exp(-t(0.15) * 25), *[after(0.1 + i * 0.07, bell(note(n), 0.8, 0.5)) for i, n in enumerate(["C6", "E6", "G6", "C7"])]), room=0.2)
    sfx("PackFull", mix(tone(220, 0.18, 0.7, decay=10, partials=((1, 1), (3, 0.3))), after(0.2, tone(180, 0.25, 0.7, decay=8, partials=((1, 1), (3, 0.3))))))
    # The base.
    sfx("Feed", mix(sweep(noise(0.9), 300, 2500) * envelope(0.9, 0.15, 3), crackle(1.2, 0.5)), room=0.15)
    sfx("HearthUp", mix(sweep(noise(1.4), 200, 3000) * envelope(1.4, 0.3, 2) * 0.6, *[after(0.15 * i, bell(note(n), 1.6, 0.5)) for i, n in enumerate(["D5", "F#5", "A5", "D6", "F#6"])]), room=0.3)
    sfx("Build", mix(thud(0.25, 0.9, 260, 140, 16), after(0.18, thud(0.25, 0.8, 280, 150, 16)), after(0.36, thud(0.3, 1.0, 240, 120, 12)), after(0.36, band(noise(0.3), 300, 3000) * np.exp(-t(0.3) * 12) * 0.4)))
    sfx("Broken", mix(band(noise(0.6), 200, 4000) * np.exp(-t(0.6) * 7), thud(0.5, 0.8, 120, 50, 6), crackle(0.6, 0.6, 80)), room=0.2)
    sfx("Repair", mix(tone(1400, 0.25, 0.5, decay=14, partials=((1, 1), (2.7, 0.4))), after(0.12, tone(1700, 0.3, 0.5, decay=12, partials=((1, 1), (2.7, 0.4))))))
    sfx("Craft", mix(tone(1180, 1.2, 0.7, decay=3, partials=((1, 1), (2.76, 0.5), (5.4, 0.25))), after(0.2, mix(*[after(i * 0.06, bell(note(n), 0.7, 0.3)) for i, n in enumerate(["E6", "G#6", "B6"])]))), room=0.25)
    bubbles = np.zeros(int(1.0 * RATE))
    for k in range(12):
        f = rng.uniform(300, 700)
        b = glide(f, f * 1.8, 0.08, 0.4, decay=20)
        at = int(rng.uniform(0, 0.9) * RATE)
        bubbles[at : at + len(b)] += b[: len(bubbles) - at]
    sfx("Cook", mix(bubbles, band(noise(1.0), 2000, 8000) * envelope(1.0, 0.1, 2) * 0.15))
    munch = mix(band(noise(0.08), 500, 3000) * np.exp(-t(0.08) * 40), after(0.14, band(noise(0.08), 500, 3000) * np.exp(-t(0.08) * 40)))
    sfx("Eat", mix(munch, after(0.32, glide(500, 900, 0.3, 0.5, decay=4, harmonics=(1, 2)))))
    # Fighting.
    sfx("Swing", sweep(noise(0.32), 600, 2600, 0.4) * envelope(0.32, 0.08, 5))
    sfx("Sling", mix(glide(420, 260, 0.2, 0.6, decay=10, harmonics=(1, 2, 3)), after(0.03, sweep(noise(0.25), 2000, 800) * envelope(0.25, 0.02, 10) * 0.6)))
    sfx("Flare", mix(thud(0.25, 0.8, 300, 120, 18), after(0.03, glide(1800, 900, 0.5, 0.25, decay=4)), after(0.02, sweep(noise(0.4), 3000, 1000) * envelope(0.4, 0.01, 8) * 0.5)))
    sfx("Blaze", mix(band(noise(0.7), 150, 2500) * envelope(0.7, 0.05, 3), crackle(0.7, 0.5, 90)))
    sfx("Cannon", mix(thud(1.0, 1.0, 130, 35, 4), band(noise(0.6), 100, 2000) * np.exp(-t(0.6) * 6) * 0.7, after(0.15, crackle(0.6, 0.4))), room=0.3)
    sfx("Hit", mix(band(noise(0.12), 800, 6000) * np.exp(-t(0.12) * 45), thud(0.15, 0.6, 300, 160, 25)))
    sfx("Poof", mix(sweep(noise(0.5), 4000, 600) * envelope(0.5, 0.01, 7), after(0.05, mix(*[after(i * 0.05, bell(note(n), 0.5, 0.25)) for i, n in enumerate(["G6", "E6", "C6"])]))))
    sfx("Slam", mix(thud(1.2, 1.0, 90, 28, 3.5), band(noise(0.8), 80, 1500) * np.exp(-t(0.8) * 5) * 0.8), room=0.35)
    growl_t = t(1.4)
    growl = saw(70, 1.4, 1.0, cutoff=500, decay=0.5) * (1 + 0.5 * np.sin(2 * np.pi * 9 * growl_t)) * np.clip((1.4 - growl_t) / 0.4, 0, 1)
    sfx("Roar", mix(growl, band(noise(1.4), 200, 1800) * envelope(1.4, 0.2, 1.5) * 0.5, glide(180, 110, 1.4, 0.3, decay=1, harmonics=(1, 2, 3))), room=0.4)
    # Warmth.
    sfx("Freeze", mix(*[after(i * 0.04, tone(rng.uniform(2500, 5000), 0.3, 0.3, decay=14)) for i in range(10)], sweep(noise(0.5), 1500, 6000) * envelope(0.5, 0.05, 5) * 0.3), room=0.25)
    sfx("Thaw", mix(*[after(i * 0.09, bell(note(n), 1.0, 0.5)) for i, n in enumerate(["A6", "E6", "C#6", "A5"])], after(0.1, band(noise(0.6), 300, 1500) * envelope(0.6, 0.1, 5) * 0.2)), room=0.25)
    sfx("Chill", mix(*[after(i * 0.12, tone(note(n), 1.0, 0.25, decay=3, partials=((1, 1), (2.01, 0.4)))) for i, n in enumerate(["E6", "B5", "G5"])]), room=0.3)
    sfx("Ability", mix(*[after(i * 0.05, bell(note(n), 0.9, 0.4)) for i, n in enumerate(["C5", "E5", "G5", "C6", "E6", "G6"])], sweep(noise(0.6), 800, 5000) * envelope(0.6, 0.1, 4) * 0.25), room=0.3)
    # The run.
    horn = mix(pad(note("D3"), 1.6, 0.6, attack=0.15, release=0.4), pad(note("A3"), 1.6, 0.4, attack=0.15, release=0.4), after(1.4, mix(pad(note("C3"), 1.8, 0.6, attack=0.15, release=0.8), pad(note("G3"), 1.8, 0.4, attack=0.15, release=0.8))))
    sfx("NightHorn", horn, room=0.45)
    sfx("DawnChime", mix(*[after(i * 0.16, bell(note(n), 2.0, 0.5)) for i, n in enumerate(["D5", "A5", "F#5", "D6", "A6"])]), room=0.4)
    sfx("IceBreak", mix(*[after(rng.uniform(0, 0.15), tone(rng.uniform(1800, 6000), 0.4, 0.25, decay=10)) for _ in range(14)], band(noise(0.4), 1500, 9000) * np.exp(-t(0.4) * 12) * 0.7), room=0.2)
    static = band(noise(0.5), 1000, 6000) * 0.25
    beeps = mix(*[after(0.1 + i * 0.12, tone(f, 0.1, 0.6, decay=4, partials=((1, 1), (3, 0.2)))) for i, f in enumerate([880, 1320, 1760])])
    sfx("RadioFit", mix(static * envelope(0.5, 0.01, 6), beeps, after(0.15, thud(0.25, 0.5, 220, 110, 16))))
    call = mix(band(noise(1.6), 900, 5000) * envelope(1.6, 0.05, 1.8) * 0.3, *[after(0.3 + i * 0.22, tone(note(n), 0.2, 0.5, decay=3, partials=((1, 1), (3, 0.3)))) for i, n in enumerate(["A5", "D6", "F#6", "A6", "F#6", "A6"])])
    sfx("Called", call, room=0.2)
    train = mix(*[pad(note(n), 1.8, 0.4, attack=0.05, release=0.3, wobble=0.002) for n in ["F4", "A4", "C5"]])
    sfx("TrainHorn", mix(train, after(2.0, mix(*[pad(note(n), 1.2, 0.4, attack=0.05, release=0.4, wobble=0.002) for n in ["F4", "A4", "C5"]]))), room=0.5)
    fanfare = [("D5", 0.0, 0.25), ("F#5", 0.18, 0.25), ("A5", 0.36, 0.25), ("D6", 0.54, 1.2)]
    sfx("Win", mix(*[after(a, square(note(n), s, 0.4)) for n, a, s in fanfare], *[after(0.54 + i * 0.1, bell(note(n), 1.6, 0.4)) for i, n in enumerate(["D6", "F#6", "A6", "D7"])]), room=0.35)
    sad = [("A4", 0.0, 0.5), ("G#4", 0.5, 0.5), ("G4", 1.0, 0.5), ("F#4", 1.5, 1.4)]
    sfx("Lose", mix(*[after(a, pad(note(n), s, 0.5, attack=0.03, release=0.2, wobble=0.012)) for n, a, s in sad]), room=0.4)
    # Menus.
    sfx("Click", mix(tone(1200, 0.05, 0.7, decay=80), band(noise(0.03), 3000, 9000) * np.exp(-t(0.03) * 120) * 0.3))
    sfx("Unlock", mix(*[after(i * 0.07, bell(note(n), 1.2, 0.5)) for i, n in enumerate(["G5", "C6", "E6", "G6", "C7"])]), room=0.3)
    sfx("Deny", mix(tone(196, 0.14, 0.6, decay=14, partials=((1, 1), (2, 0.5), (3, 0.3))), after(0.12, tone(165, 0.2, 0.6, decay=10, partials=((1, 1), (2, 0.5), (3, 0.3))))))
    sfx("Notice", tone(1568, 0.25, 0.5, decay=14, partials=((1, 1), (2.76, 0.3))))


def main():
    if subprocess.run(["ffmpeg", "-version"], capture_output=True).returncode != 0:
        sys.exit("ffmpeg is needed on the path")
    make_effects()
    wind()
    music_day()
    music_night()
    music_boss()


if __name__ == "__main__":
    main()
