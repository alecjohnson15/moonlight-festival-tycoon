"""Makes Phantom Party's original sounds and music from scratch.

Every sound is synthesised here from sine waves and noise, so the project
owns all of it outright. Run it with Python 3 and numpy, with ffmpeg on the
path for OGG encoding, from the games/phantom-party folder:

    python3 tools/make_sounds.py            # every sound
    python3 tools/make_sounds.py tag zap    # just these

It writes assets/audio/*.ogg, one file per entry in
src/shared/Config/Sounds.luau. Upload them to Roblox and paste each asset id
into that file (docs/launch.md has the steps).

The building blocks (tones, drums, the Song mixer) are the same ones the
Halloween Tycoon's tools/make_sounds.py uses. Every tune here was written for
this game; none is a cover, remix or soundalike of an existing song.
"""

import os
import subprocess
import sys

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2027)
def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def note(name):
    """Frequency of a note name such as "D5" or "Bb3"."""
    steps = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
    semitone = steps[name[0]]
    rest = name[1:]
    if rest.startswith("b"):
        semitone -= 1
        rest = rest[1:]
    elif rest.startswith("#"):
        semitone += 1
        rest = rest[1:]
    midi = 12 * (int(rest) + 1) + semitone
    return 440.0 * 2 ** ((midi - 69) / 12)


def music_box(freq, seconds, amp=1.0):
    """A plucked metal tine: a few inharmonic partials that die away."""
    t = times(seconds)
    partials = [(1, 1.0, 2.2), (2.76, 0.35, 5), (5.4, 0.15, 9), (8.93, 0.06, 14)]
    sound = sum(level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay) for ratio, level, decay in partials)
    return amp * sound * np.minimum(1, t / 0.002)


def bell(freq, seconds, amp=1.0):
    """A heavier, longer bell for tolls and gongs."""
    t = times(seconds)
    partials = [(0.5, 0.5, 0.7), (1, 1.0, 1.2), (1.19, 0.5, 1.6), (1.56, 0.4, 2), (2, 0.3, 2.6), (2.74, 0.2, 3.5)]
    sound = sum(level * np.sin(2 * np.pi * freq * ratio * t) * np.exp(-t * decay) for ratio, level, decay in partials)
    return amp * sound * np.minimum(1, t / 0.004)


def organ(freq, seconds, amp=1.0, attack=0.6, release=0.8):
    """A soft drone with a slight wobble, swelling in and out."""
    t = times(seconds)
    wobble = 1 + 0.003 * np.sin(2 * np.pi * 5 * t)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / RATE
    sound = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.25 * np.sin(3 * phase) + 0.12 * np.sin(4 * phase)
    shape = np.minimum(1, t / attack) * np.minimum(1, (seconds - t) / release)
    return amp * sound * np.clip(shape, 0, 1)


def thud(seconds=0.6, amp=1.0, start=90, end=40):
    """A low drum hit, like a heartbeat."""
    t = times(seconds)
    freq = end + (start - end) * np.exp(-t * 12)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    return amp * np.sin(phase) * np.exp(-t * 7) * np.minimum(1, t / 0.003)


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


def reseed(seed):
    """Gives each sound its own random sequence, so changing one sound
    doesn't change the others."""
    global rng
    rng = np.random.default_rng(seed)


def band(signal, low, high):
    """Keeps only frequencies between low and high, with soft edges."""
    spectrum = np.fft.rfft(signal)
    freqs = np.fft.rfftfreq(len(signal), 1 / RATE)
    gain = 1 / (1 + (low / np.maximum(freqs, 1)) ** 4) / (1 + (freqs / high) ** 4)
    return np.fft.irfft(spectrum * gain, len(signal))


def sweep(signal, start, end):
    """A band of noise whose centre slides from start to end, block by block."""
    out = np.zeros_like(signal)
    block = 2048
    count = int(np.ceil(len(signal) / block))
    for i in range(count):
        centre = start * (end / start) ** (i / max(count - 1, 1))
        piece = signal[i * block : (i + 1) * block]
        out[i * block : i * block + len(piece)] = band(piece, centre * 0.7, centre * 1.4)
    return out


def reverb(signal, seconds=2.5, wet=0.35, seed=0):
    """Convolves with a burst of decaying noise, for a big dark room."""
    local = np.random.default_rng(seed)
    t = times(seconds)
    impulse = local.standard_normal(len(t)) * np.exp(-t * 3.2)
    impulse = band(impulse, 120, 5000)
    impulse /= np.sqrt(np.sum(impulse**2))
    size = len(signal) + len(impulse)
    wet_signal = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)[: len(signal) + len(impulse)]
    dry = np.concatenate([signal, np.zeros(len(impulse))])
    return dry * (1 - wet) + wet_signal * wet * 3


def place(track, sound, at):
    start = int(at * RATE)
    if start < 0:
        sound, start = sound[-start:], 0
    end = min(len(track), start + len(sound))
    track[start:end] += sound[: end - start]


def loop(track, length):
    """Folds everything past length back onto the start, so it loops cleanly."""
    samples = int(length * RATE)
    out = track[:samples].copy()
    tail = track[samples:]
    out[: len(tail)] += tail[:samples]
    return out


def normalise(signal, peak=0.89):
    return signal * peak / np.max(np.abs(signal))


def write(name, channels):
    os.makedirs(OUT, exist_ok=True)
    channels = [np.asarray(c, dtype=np.float32) for c in channels]
    data = np.stack(channels, axis=1) if len(channels) > 1 else channels[0][:, None]
    path = os.path.join(OUT, f"{name}.ogg")
    subprocess.run(
        [
            "ffmpeg", "-y", "-loglevel", "error",
            "-f", "f32le", "-ar", str(RATE), "-ac", str(len(channels)), "-i", "pipe:",
            "-c:a", "libvorbis", "-q:a", "4", path,
        ],
        input=data.tobytes(),
        check=True,
    )
    print(f"wrote {path} ({os.path.getsize(path) // 1024} KB)")


# Music. Each tune is a loop with a pop shape (a hooky melody over a short
# chord loop, punchy drums and a pumping bass) dressed in party-at-midnight
# sounds: harpsichord, an organ, music boxes and a theremin.

STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}

CHORDS = {
    "Am": ("A", "C", "E"),
    "Dm": ("D", "F", "A"),
    "Gm": ("G", "Bb", "D"),
    "F": ("F", "A", "C"),
    "C": ("C", "E", "G"),
    "G": ("G", "B", "D"),
    "E": ("E", "G#", "B"),
    "A": ("A", "C#", "E"),
    "Bb": ("Bb", "D", "F"),
    "Em": ("E", "G", "B"),
    "D": ("D", "F#", "A"),
}


def pitch_class(tone):
    value = STEPS[tone[0]]
    if tone[1:] == "b":
        value -= 1
    elif tone[1:] == "#":
        value += 1
    return value % 12


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def voicing(chord, low):
    """The chord's tones as MIDI notes, each in the octave from low up."""
    return sorted(low + (pitch_class(tone) - low) % 12 for tone in CHORDS[chord])


def smooth(signal, seconds):
    """A one-pole smoother, done as an FFT convolution so it runs fast."""
    t = times(seconds * 6)
    kernel = np.exp(-t / seconds)
    kernel /= kernel.sum()
    size = len(signal) + len(kernel)
    out = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(kernel, size), size)
    return out[: len(signal)]


def kick(amp=1.0):
    t = times(0.45)
    freq = 48 + 110 * np.exp(-t * 28)
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 7)
    click = band(noise(0.45), 1500, 6000) * np.exp(-t * 120) * 0.3
    return amp * (body + click) * np.minimum(1, t / 0.001)


def snare(amp=1.0):
    t = times(0.3)
    tone = np.sin(2 * np.pi * 185 * t) * np.exp(-t * 30) * 0.5
    return amp * (tone + band(noise(0.3), 1200, 9000) * np.exp(-t * 16))


def clap(amp=1.0):
    t = times(0.35)
    shape = sum(np.where(t >= d, np.exp(-(t - d) * 90), 0) for d in (0, 0.011, 0.022))
    shape = shape + np.where(t >= 0.03, np.exp(-(t - 0.03) * 14) * 0.6, 0)
    return amp * band(noise(0.35), 900, 6000) * shape


def hat(amp=1.0, open_hat=False):
    seconds = 0.35 if open_hat else 0.08
    t = times(seconds)
    return amp * band(noise(seconds), 7000, 16000) * np.exp(-t * (11 if open_hat else 70))


def crash(amp=1.0):
    t = times(2.0)
    return amp * band(noise(2.0), 3000, 15000) * np.exp(-t * 2.2)


def saw_bass(freq, seconds, amp=1.0, cutoff=700):
    """A round, plucky synth bass: a saw wave with its top rolled off."""
    t = times(seconds + 0.05)
    out = np.zeros_like(t)
    harmonic = 1
    while freq * harmonic < 6000:
        out += np.sin(2 * np.pi * freq * harmonic * t) / harmonic / (1 + (freq * harmonic / cutoff) ** 2)
        harmonic += 1
    shape = np.minimum(1, t / 0.004) * (0.55 + 0.45 * np.exp(-t * 8))
    return amp * out * shape * np.clip((seconds + 0.05 - t) / 0.05, 0, 1)


def pluck(freq, seconds, amp=1.0, bright=False):
    """A short synth pluck, or with bright, a harpsichord-like one."""
    t = times(seconds)
    harmonics = range(1, 13) if bright else (1, 3, 5, 7, 9)
    out = sum(np.sin(2 * np.pi * freq * n * t) * np.exp(-t * (5 + n * 1.5)) / n for n in harmonics)
    return amp * out * np.minimum(1, t / 0.002)


def square_lead(freq, seconds, amp=1.0):
    """A hollow, arcade-style lead whose vibrato creeps in on long notes."""
    t = times(seconds + 0.08)
    wobble = 1 + 0.005 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.3)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / RATE
    out = sum(np.sin(n * phase) / n for n in (1, 3, 5, 7, 9, 11)) + 0.3 * np.sin(2 * phase)
    shape = np.minimum(1, t / 0.01) * (0.7 + 0.3 * np.exp(-t * 6))
    return amp * out * shape * np.clip((seconds + 0.08 - t) / 0.08, 0, 1)


def theremin(phrase, beat, amp=1.0, glide=0.05, vibrato=0.006):
    """A phrase on a theremin: one wavering tone that slides between notes."""
    total = sum(beats for _, beats in phrase) * beat
    t = times(total + 0.5)
    freq = np.zeros_like(t)
    level = np.zeros_like(t)
    # Rests hold the last pitch (or the first, before any note) in silence.
    at, last = 0.0, next(note(name) for name, _ in phrase if name)
    for name, beats in phrase:
        start, end = int(at * RATE), int((at + beats * beat) * RATE)
        if name:
            last = note(name)
            level[start : end - int(0.12 * beats * beat * RATE)] = 1
        freq[start:end] = last
        at += beats * beat
    freq[int(at * RATE) :] = last
    curve = np.exp(smooth(np.log(np.maximum(freq, 1)), glide))
    curve *= 1 + vibrato * np.sin(2 * np.pi * 5.5 * t)
    phase = 2 * np.pi * np.cumsum(curve) / RATE
    tone = np.sin(phase) + 0.25 * np.sin(2 * phase) + 0.08 * np.sin(3 * phase)
    return amp * tone * smooth(level, 0.025)


class Song:
    """Places sounds on a few stereo buses, then mixes them into a loop."""

    BUSES = ("drums", "bass", "keys", "lead", "bells")

    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.bar = self.beat * 4
        self.length = bars * self.bar
        samples = int((self.length + 6) * RATE)
        self.buses = {name: np.zeros((2, samples)) for name in self.BUSES}
        self.kicks = []

    def at(self, bar, beat=0.0):
        return bar * self.bar + beat * self.beat

    def add(self, bus, sound, at, pan=0.0):
        place(self.buses[bus][0], sound * np.sqrt((1 - pan) / 2), at)
        place(self.buses[bus][1], sound * np.sqrt((1 + pan) / 2), at)

    def kick(self, at, amp=0.9):
        self.add("drums", kick(amp), at)
        self.kicks.append(at)

    def mix(self, name):
        # Bass and keys duck under each kick, for the pumping pop feel.
        duck = np.ones(self.buses["bass"].shape[1])
        for at in self.kicks:
            start = int(at * RATE)
            t = times(0.3)
            end = min(len(duck), start + len(t))
            duck[start:end] *= 1 - 0.55 * np.exp(-t[: end - start] / 0.08)
        self.buses["bass"] *= duck
        self.buses["keys"] *= duck

        # A dotted-eighth echo on the lead, bouncing between the speakers.
        lead = self.buses["lead"]
        gap = int(self.beat * 0.75 * RATE)
        echo = np.zeros_like(lead)
        echo[0, gap:] += lead[1, :-gap] * 0.28
        echo[1, gap:] += lead[0, :-gap] * 0.28
        echo[0, 2 * gap :] += lead[0, : -2 * gap] * 0.12
        self.buses["lead"] = lead + echo

        rooms = {"drums": 0.12, "bass": 0.0, "keys": 0.25, "lead": 0.3, "bells": 0.45}
        channels = []
        for side in (0, 1):
            total = np.zeros(int(self.length * RATE))
            for bus, wet in rooms.items():
                signal = self.buses[bus][side]
                if wet > 0:
                    signal = reverb(signal, seconds=2, wet=wet, seed=side * 10 + len(bus))
                total += loop(signal, self.length)
            channels.append(total)
        peak = max(np.max(np.abs(c)) for c in channels)
        channels = [np.tanh(c / peak * 1.3) / np.tanh(1.3) * 0.8 for c in channels]
        write(name, channels)


def make_song(name, bpm, voice, progressions, melodies, groove):
    """Thirty-two bars: intro, verse, pre-chorus, chorus, a spooky break and
    the hook again, which leads straight back into the intro."""
    song = Song(bpm, 32)
    sections = [
        ("intro", 0, 4),
        ("verse", 4, 8),
        ("pre", 12, 4),
        ("chorus", 16, 8),
        ("break", 24, 4),
        ("hook", 28, 4),
    ]
    beat = song.beat
    for section, first, count in sections:
        chords = progressions[section]
        for i in range(count):
            bar = first + i
            chord = chords[i % len(chords)]
            # The bass root sits between E1 and D#2.
            root = 28 + (pitch_class(CHORDS[chord][0]) - 28) % 12
            pad = voicing(chord, 55)
            top = voicing(chord, 67)

            # Drums.
            if section == "intro":
                for eighth in range(8):
                    song.add("drums", hat(0.18 + 0.08 * (eighth % 2)), song.at(bar, eighth / 2), 0.3)
                if i >= 2:
                    song.kick(song.at(bar), 0.6)
            elif section in ("verse", "hook"):
                groove(song, bar, full=False)
            elif section == "chorus":
                if i == 0:
                    song.add("drums", crash(0.35), song.at(bar), -0.2)
                groove(song, bar, full=True)
            elif section == "pre":
                for b in range(4):
                    song.kick(song.at(bar, b), 0.85)
                hits = 8 if i < 3 else 16
                if i >= 2:
                    for h in range(hits):
                        rise = (i - 2 + h / hits) / 2
                        song.add("drums", snare(0.15 + 0.35 * rise), song.at(bar, h * 4 / hits), 0.1)
                if i == 2:
                    riser = sweep(noise(song.bar * 2), 400, 8000) * np.linspace(0, 1, int(song.bar * 2 * RATE)) ** 2
                    song.add("drums", riser * 0.25, song.at(bar))
            elif section == "break":
                for b in (0, 2):
                    song.add("drums", thud(amp=0.7), song.at(bar, b))
                    song.add("drums", thud(amp=0.45), song.at(bar, b + 0.5))

            # Bass.
            if section in ("verse", "chorus", "hook"):
                for eighth in range(8):
                    note_midi = root + (12 if eighth % 2 else 0)
                    song.add("bass", saw_bass(hz(note_midi), beat * 0.45, 0.34), song.at(bar, eighth / 2))
            elif section == "pre":
                for b in range(4):
                    song.add("bass", saw_bass(hz(root), beat * 0.9, 0.45), song.at(bar, b))
            elif section == "break":
                song.add("bass", saw_bass(hz(root), song.bar * 0.95, 0.4, cutoff=300), song.at(bar))

            # Keys: an organ pad, arpeggios and off-beat organ stabs.
            if section in ("intro", "verse", "pre", "break"):
                level = 0.06 if section in ("verse", "break") else 0.09
                for m in pad:
                    song.add("keys", organ(hz(m), song.bar + 0.3, level, attack=0.3, release=0.4), song.at(bar), -0.2)
            if section in ("intro", "verse", "chorus", "hook") or (section == "pre" and i < 2):
                tones = top + [top[0] + 12]
                order = [0, 1, 2, 3, 2, 1, 2, 3, 0, 1, 2, 3, 2, 3, 1, 2]
                level = 0.09 if section == "intro" else 0.12
                for step in range(16):
                    m = tones[order[step]]
                    song.add("keys", pluck(hz(m), beat * 0.6, level, bright=voice != "theremin"), song.at(bar, step / 4), 0.45 if step % 2 else -0.45)
            if section == "chorus":
                for b in range(4):
                    for m in pad:
                        song.add("keys", organ(hz(m), beat * 0.35, 0.07, attack=0.008, release=0.08), song.at(bar, b + 0.5), -0.3)

            # Bells on the first beat of each section and through the break.
            if i == 0 and section in ("intro", "break"):
                song.add("bells", bell(hz(root + 12), 5, 0.35), song.at(bar))
            if section in ("intro", "break"):
                for k, m in enumerate(top):
                    song.add("bells", music_box(hz(m + 12), 2, 0.18), song.at(bar, k * 0.5 + (2 if i % 2 else 0)), 0.5)

        # The tune.
        phrase = melodies.get(section)
        if phrase:
            flat = [n for bar_notes in phrase for n in bar_notes]
            start = song.at(first)
            if voice == "theremin" or section == "break":
                glide = 0.22 if section == "break" else 0.05
                wobble = 0.012 if section == "break" else 0.006
                level = 0.3 if section in ("chorus", "hook") else 0.2 if section == "break" else 0.24
                song.add("lead", theremin(flat, beat, level, glide, wobble), start, 0.05)
            else:
                at = start
                for name_, beats in flat:
                    if name_:
                        loud = 0.26 if section in ("chorus", "hook") else 0.22
                        song.add("lead", square_lead(note(name_), beats * beat * 0.9, loud), at, 0.05)
                    at += beats * beat
            if section in ("chorus", "hook"):
                at = start
                for name_, beats in flat:
                    if name_:
                        boost = 0.2 if section == "hook" else 0.14
                        song.add("bells", music_box(note(name_) * 2, 1.5, boost), at, -0.35)
                    at += beats * beat
    song.mix(name)


def four_on_the_floor(song, bar, full):
    for b in range(4):
        song.kick(song.at(bar, b))
    for b in (1, 3):
        song.add("drums", clap(0.5), song.at(bar, b), 0.05)
    for eighth in range(8):
        offbeat = eighth % 2 == 1
        if full and offbeat:
            song.add("drums", hat(0.22, open_hat=True), song.at(bar, eighth / 2), 0.3)
        else:
            song.add("drums", hat(0.2 + (0.1 if offbeat else 0)), song.at(bar, eighth / 2), 0.3)
    if full:
        for sixteenth in range(16):
            song.add("drums", hat(0.07), song.at(bar, sixteenth / 4 + 0.125), -0.4)


def bounce(song, bar, full):
    for b in (0, 1.75, 2):
        song.kick(song.at(bar, b), 0.85)
    for b in (1, 3):
        song.add("drums", snare(0.45), song.at(bar, b), 0.05)
        if full:
            song.add("drums", clap(0.25), song.at(bar, b), -0.1)
    for sixteenth in range(16):
        accent = 0.16 if sixteenth % 4 == 2 else 0.08
        song.add("drums", hat(accent, open_hat=full and sixteenth % 8 == 6), song.at(bar, sixteenth / 4), 0.35)



def mono(track, seconds, wet=0.25, room=1.0, seed=0, peak=0.89):
    """Adds a little room and writes a one-channel sound."""
    out = reverb(track, seconds=room, wet=wet, seed=seed)[: int(seconds * RATE)]
    return normalise(out, peak)


def glide_tone(start, end, seconds, amp=1.0, shape="sine", curve=6.0):
    """One tone sliding from start to end Hz, fast at first."""
    t = times(seconds)
    freq = end + (start - end) * np.exp(-t * curve / seconds)
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    if shape == "square":
        tone = sum(np.sin(n * phase) / n for n in (1, 3, 5, 7))
    elif shape == "saw":
        tone = sum(np.sin(n * phase) / n for n in range(1, 9))
    else:
        tone = np.sin(phase)
    return amp * tone * np.minimum(1, t / 0.003)


# The music ------------------------------------------------------------------


def make_lobby_music():
    """Masquerade Mixer: F major at 120 bpm on a square lead and harpsichord.
    The plaza's party tune: bright, bouncy and easy to hang out to."""
    reseed(101)
    make_song(
        "music_lobby",
        120,
        "square",
        {
            "intro": ["F", "Dm", "Bb", "C"],
            "verse": ["F", "Dm", "Bb", "C"],
            "pre": ["Gm", "Gm", "C", "C"],
            "chorus": ["Bb", "C", "Am", "Dm"],
            "break": ["Dm", "Bb", "F", "C"],
            "hook": ["Bb", "C", "F", "F"],
        },
        {
            "verse": [
                [("C5", 0.5), ("F5", 0.5), ("A5", 1), ("G5", 0.5), ("F5", 0.5), ("C5", 1)],
                [("D5", 1), ("F5", 0.5), ("A5", 0.5), ("G5", 2)],
                [("Bb4", 0.5), ("D5", 0.5), ("F5", 1), ("E5", 0.5), ("D5", 0.5), ("Bb4", 1)],
                [("C5", 1.5), ("E5", 0.5), ("G5", 1), (None, 1)],
                [("C5", 0.5), ("F5", 0.5), ("A5", 1), ("C6", 0.5), ("A5", 0.5), ("F5", 1)],
                [("D5", 0.5), ("F5", 0.5), ("A5", 0.5), ("D6", 0.5), ("C6", 2)],
                [("Bb5", 0.5), ("A5", 0.5), ("G5", 0.5), ("F5", 0.5), ("D5", 1), ("F5", 1)],
                [("E5", 1.5), ("G5", 0.5), ("C5", 2)],
            ],
            "pre": [
                [("G5", 1), ("Bb5", 1), ("D6", 2)],
                [("C6", 1), ("Bb5", 1), ("G5", 2)],
                [("E5", 1), ("G5", 1), ("C6", 2)],
                [("C6", 0.5), ("D6", 0.5), ("E6", 0.5), ("G6", 0.5), ("E6", 2)],
            ],
            "chorus": [
                [("F5", 0.5), ("F5", 0.5), ("D6", 1), ("C6", 0.5), ("Bb5", 0.5), ("F5", 1)],
                [("G5", 0.5), ("G5", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("G5", 1)],
                [("A5", 0.5), ("C6", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("A5", 1)],
                [("F5", 1), ("A5", 0.5), ("D6", 0.5), ("D6", 2)],
                [("F5", 0.5), ("F5", 0.5), ("D6", 1), ("C6", 0.5), ("Bb5", 0.5), ("D6", 1)],
                [("E6", 1), ("D6", 0.5), ("C6", 0.5), ("G6", 1), ("E6", 1)],
                [("F6", 0.75), ("E6", 0.75), ("C6", 0.5), ("A5", 1), ("C6", 1)],
                [("D6", 1.5), ("C6", 0.5), ("A5", 1), (None, 1)],
            ],
            "break": [
                [("A5", 4)],
                [("F5", 2), ("D5", 2)],
                [("C5", 2), ("F5", 2)],
                [("E5", 2), ("G5", 2)],
            ],
            "hook": [
                [("F5", 0.5), ("F5", 0.5), ("D6", 1), ("C6", 0.5), ("Bb5", 0.5), ("F5", 1)],
                [("G5", 0.5), ("G5", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("G5", 1)],
                [("A5", 0.5), ("C6", 0.5), ("F6", 1), ("E6", 0.5), ("C6", 0.5), ("A5", 1)],
                [("C6", 1.5), ("A5", 0.5), ("F5", 2)],
            ],
        },
        bounce,
    )


def make_round_music():
    """Sneaking Suspicion: A minor at 100 bpm. A tiptoeing pizzicato bass,
    soft ticks and a music-box motif, with a theremin in the middle. Quiet
    enough to hear footsteps over."""
    reseed(102)
    bars = 16
    song = Song(100, bars)
    beat = song.beat
    walk = [
        ["A2", "C3", "D3", "D#3"],
        ["E3", "D3", "C3", "B2"],
        ["F2", "A2", "C3", "A2"],
        ["E2", "G#2", "B2", "E3"],
    ]
    pads = [("A3", "C4", "E4"), ("A3", "C4", "E4"), ("F3", "A3", "C4"), ("E3", "G#3", "B3")]
    motif = [
        [("E5", 0.5), (None, 0.5), ("C5", 0.5), (None, 0.5), ("D#5", 0.5), ("E5", 0.5), (None, 1)],
        [("B4", 0.5), (None, 0.5), ("C5", 0.5), ("D5", 0.5), ("C5", 0.5), ("B4", 0.5), ("A4", 1)],
    ]
    for bar in range(bars):
        cycle = bar % 4
        for b, name in enumerate(walk[cycle]):
            song.add("bass", pluck(note(name), beat * 0.8, 0.55), song.at(bar, b), -0.1)
        for eighth in range(8):
            if eighth % 2 == 1:
                song.add("drums", hat(0.1), song.at(bar, eighth / 2), 0.35)
        for b in (1, 3):
            song.add("drums", music_box(1900, 0.12, 0.12), song.at(bar, b), -0.4)
        for name in pads[cycle]:
            song.add("keys", organ(note(name), song.bar + 0.2, 0.035, attack=0.5, release=0.5), song.at(bar), -0.2)
        if bar >= 8:
            song.add("drums", thud(amp=0.5), song.at(bar))
            song.add("drums", thud(amp=0.3), song.at(bar, 0.4))
        if 4 <= bar < 8 or bar >= 12:
            at = song.at(bar)
            for name, beats in motif[bar % 2]:
                if name:
                    song.add("bells", music_box(note(name), 1.2, 0.3), at, 0.3)
                at += beats * beat
    phrase = [("A5", 4), ("G#5", 2), ("F5", 2), ("E5", 4), (None, 4)]
    song.add("lead", theremin(phrase, beat, 0.16, glide=0.2, vibrato=0.012), song.at(8), 0.05)
    song.mix("music_round")


def make_final_music():
    """Last Thirty: D minor at 150 bpm. Driving kicks, a racing bass, organ
    stabs and a clock ticking above it all, for the final half minute."""
    reseed(103)
    bars = 16
    song = Song(150, bars)
    beat = song.beat
    chords = ["Dm", "Bb", "Gm", "A"]
    riff = [0, 7, 12, 7, 0, 7, 10, 7]
    for bar in range(bars):
        chord = chords[bar % 4]
        root = 38 + (pitch_class(CHORDS[chord][0]) - 38) % 12
        four_on_the_floor(song, bar, full=bar >= 4)
        for sixteenth in range(16):
            song.add("bass", saw_bass(hz(root), beat * 0.22, 0.3, cutoff=900), song.at(bar, sixteenth / 4))
        for b in range(4):
            for m in voicing(chord, 57):
                song.add("keys", organ(hz(m), beat * 0.3, 0.06, attack=0.005, release=0.06), song.at(bar, b + 0.5), -0.3)
        for b in range(4):
            song.add("bells", music_box(2637 if b % 2 == 0 else 2349, 0.3, 0.14), song.at(bar, b), 0.5)
        if bar >= 4:
            lift = 12 if bar >= 12 else 0
            for step, offset in enumerate(riff):
                m = root + 36 + offset + lift - (12 if root + 36 + offset + lift > 86 else 0)
                song.add("lead", square_lead(hz(m), beat * 0.4, 0.16), song.at(bar, step / 2), 0.05)
        if bar in (7, 15):
            riser = sweep(noise(song.bar), 500, 9000) * np.linspace(0, 1, int(song.bar * RATE)) ** 2
            song.add("drums", riser * 0.3, song.at(bar))
        if bar in (0, 8):
            song.add("drums", crash(0.35), song.at(bar), -0.2)
    song.mix("music_final")


# Ambience -------------------------------------------------------------------


def make_manor_ambience():
    """Midnight Manor: wind at the windows, a grandfather clock, creaking
    floorboards and far-off thunder. A 48 second loop."""
    reseed(104)
    length = 48
    track = np.zeros(int((length + 4) * RATE))
    t = times(length)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12) * np.sin(2 * np.pi * t / 8 + 1)
    wind = band(noise(length), 250, 900) * (0.3 + 0.7 * gust)
    howl = band(noise(length), 500, 700) * (gust**3) * 2
    track[: len(t)] += wind * 0.45 + howl * 0.35
    track += organ(note("D2"), len(track) / RATE, 0.04, attack=4, release=4)
    for second in range(length):
        tock = music_box(900 if second % 2 else 1100, 0.08, 0.05)
        place(track, band(tock + band(noise(0.08), 1500, 4000) * np.exp(-times(0.08) * 80) * 0.04, 300, 5000), second + 0.02)
    for at in (5, 19, 33, 41):
        seconds = rng.uniform(0.6, 1.2)
        ct = times(seconds)
        freq = rng.uniform(180, 260) * (1 + 0.4 * ct / seconds)
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        creak = np.sign(np.sin(phase)) * np.sin(phase * 0.5) * np.exp(-((ct - seconds / 2) ** 2) / (seconds / 4) ** 2)
        place(track, band(creak, 150, 2500) * 0.1, at)
    for at in (10, 30):
        rumble = band(noise(5), 30, 160) * np.exp(-times(5) * 0.9) * np.minimum(1, times(5) / 0.3)
        place(track, rumble * 1.6, at)
    for at in (24,):
        place(track, bell(note("A2"), 6, 0.1), at)
    left = loop(reverb(track, seconds=3, wet=0.45, seed=5), length)
    right = loop(reverb(track, seconds=3, wet=0.45, seed=6), length)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    write("ambience_manor", [left * 0.75 / peak, right * 0.75 / peak])


def make_carnival_ambience():
    """Starlight Carnival: a far-off calliope waltz, a murmuring crowd, booth
    bells and the rumble of the rides. A 38.4 second loop."""
    reseed(105)
    bar = 1.2
    bars = 32
    length = bar * bars
    track = np.zeros(int((length + 4) * RATE))
    tune = [
        [("E5", 3)], [("G5", 1), ("F5", 1), ("E5", 1)], [("D5", 3)], [("F5", 1), ("E5", 1), ("D5", 1)],
        [("C5", 2), ("E5", 1)], [("G5", 2), ("C6", 1)], [("B5", 3)], [("G5", 3)],
        [("A5", 1), ("G5", 1), ("F5", 1)], [("E5", 3)], [("F5", 1), ("E5", 1), ("D5", 1)], [("C5", 3)],
        [("D5", 1), ("E5", 1), ("F5", 1)], [("G5", 2), ("B4", 1)], [("C5", 3)], [(None, 3)],
    ]
    chords = ["C", "C", "G", "G", "C", "C", "G", "G", "F", "C", "G", "C", "F", "G", "C", "C"]
    beat = bar / 3
    for index in range(bars):
        phrase = tune[index % 16]
        chord = chords[index % 16]
        start = index * bar
        root = 48 + (pitch_class(CHORDS[chord][0]) - 48) % 12
        place(track, organ(hz(root), beat * 0.8, 0.1, attack=0.01, release=0.1), start)
        for b in (1, 2):
            for m in voicing(chord, 60):
                place(track, organ(hz(m), beat * 0.5, 0.04, attack=0.01, release=0.08), start + b * beat)
        at = start
        for name, beats in phrase:
            if name:
                place(track, organ(note(name), beats * beat * 0.9, 0.09, attack=0.01, release=0.1), at)
                place(track, music_box(note(name) * 2, 0.6, 0.05), at)
            at += beats * beat
    track = band(track, 200, 3500)
    t = times(length)
    murmur = band(noise(length), 300, 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * t / 9.6) * np.sin(2 * np.pi * t / 6.4))
    track[: len(t)] += murmur * 0.08
    rumble = band(noise(length), 40, 200) * (0.5 + 0.5 * np.sin(2 * np.pi * t / 19.2))
    track[: len(t)] += rumble * 0.12
    for at in (3.1, 11.7, 20.2, 29.5, 35.0):
        place(track, music_box(rng.uniform(1400, 2200), 0.8, 0.06), at)
        place(track, music_box(rng.uniform(1400, 2200), 0.8, 0.05), at + 0.15)
    left = loop(reverb(track, seconds=2.5, wet=0.55, seed=7), length)
    right = loop(reverb(track, seconds=2.5, wet=0.55, seed=8), length)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    write("ambience_carnival", [left * 0.7 / peak, right * 0.7 / peak])


# Stings -----------------------------------------------------------------------


def make_reveal_shadow():
    """Your role is the Phantom or the Saboteur: a low hit, a sinister organ
    chord and a whisper of wind rushing in backwards."""
    reseed(110)
    seconds = 3.2
    track = np.zeros(int(seconds * RATE))
    rush = sweep(noise(0.8), 3000, 300) * np.linspace(0, 1, int(0.8 * RATE)) ** 3
    place(track, rush * 0.5, 0)
    place(track, thud(1.4, 1.0, 80, 32), 0.8)
    for name in ("D3", "F3", "Ab3", "B3"):
        place(track, organ(note(name), 2.2, 0.16, attack=0.05, release=1.2), 0.8)
    place(track, bell(note("D3"), 2.4, 0.25), 0.8)
    write("reveal_shadow", [mono(track, seconds, wet=0.4, room=2, seed=110)])


def make_reveal_guest():
    """Your role is a guest: a bright bell and a rising music-box arpeggio."""
    reseed(111)
    seconds = 2.4
    track = np.zeros(int(seconds * RATE))
    place(track, bell(note("C5"), 2, 0.35), 0)
    for i, name in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        place(track, music_box(note(name), 1.2, 0.45), 0.05 + i * 0.09)
    place(track, organ(note("C4"), 1.6, 0.08, attack=0.05, release=0.8), 0)
    write("reveal_guest", [mono(track, seconds, wet=0.3, room=1.5, seed=111, peak=0.8)])


def make_win_guests():
    """The guests win: a short, bright brass-like fanfare with bells."""
    reseed(112)
    seconds = 3.4
    track = np.zeros(int(seconds * RATE))
    line = [("G4", 0.0, 0.18), ("C5", 0.18, 0.18), ("E5", 0.36, 0.18), ("G5", 0.54, 0.5), ("E5", 1.04, 0.18), ("G5", 1.22, 1.4)]
    for name, at, length in line:
        place(track, saw_bass(note(name), length, 0.35, cutoff=2400), at)
        place(track, saw_bass(note(name) * 1.5, length, 0.12, cutoff=2400), at)
    for m in ("C4", "E4", "G4"):
        place(track, organ(note(m), 2.2, 0.1, attack=0.05, release=1), 1.22)
    place(track, crash(0.4), 1.22)
    place(track, kick(0.8), 1.22)
    for i, name in enumerate(["C6", "E6", "G6", "C7"]):
        place(track, music_box(note(name), 1.4, 0.25), 1.3 + i * 0.1)
    write("win_guests", [mono(track, seconds, wet=0.3, room=1.5, seed=112)])


def make_win_phantom():
    """The Phantom wins: a falling organ line, a low gong and a theremin
    sliding down into the dark."""
    reseed(113)
    seconds = 3.8
    track = np.zeros(int(seconds * RATE))
    for i, name in enumerate(["A4", "F4", "D4", "C#4"]):
        place(track, organ(note(name), 0.6 if i < 3 else 2.2, 0.16, attack=0.02, release=0.3), i * 0.3)
    for name in ("D3", "F3", "A3"):
        place(track, organ(note(name), 2.6, 0.08, attack=0.05, release=1.2), 0.9)
    place(track, bell(note("D2"), 3, 0.5), 0.9)
    place(track, thud(1.5, 0.9, 70, 30), 0.9)
    place(track, theremin([("D5", 1), ("A4", 1), ("D4", 2)], 0.5, 0.18, glide=0.25, vibrato=0.015), 1.2)
    write("win_phantom", [mono(track, seconds, wet=0.4, room=2, seed=113)])


# The round ----------------------------------------------------------------------


def make_draw():
    """A blade drawn: a bright metallic shing."""
    reseed(120)
    seconds = 0.7
    track = np.zeros(int(seconds * RATE))
    scrape = sweep(noise(0.25), 2500, 9000) * np.sin(np.pi * times(0.25) / 0.25) ** 2
    place(track, scrape * 0.5, 0)
    place(track, music_box(3520, 0.5, 0.35), 0.2)
    place(track, music_box(4700, 0.4, 0.18), 0.2)
    write("draw", [mono(track, seconds, wet=0.15, room=0.6, seed=120, peak=0.8)])


def make_swing():
    """A quick swish of air."""
    reseed(121)
    length = 0.35
    swish = sweep(noise(length), 400, 3000) * np.sin(np.pi * times(length) / length) ** 3
    write("swing", [mono(swish, 0.45, wet=0.1, room=0.4, seed=121, peak=0.8)])


def make_throw():
    """A thrown blade spinning away: a fluttering whoosh."""
    reseed(122)
    length = 0.7
    t = times(length)
    flutter = 0.55 + 0.45 * np.sin(2 * np.pi * 22 * t)
    swish = sweep(noise(length), 2600, 700) * flutter * np.sin(np.pi * t / length) ** 2
    write("throw", [mono(swish, 0.8, wet=0.12, room=0.5, seed=122, peak=0.8)])


def make_tag():
    """A cartoon knockout: a soft bonk and a springy boing."""
    reseed(123)
    seconds = 0.9
    track = np.zeros(int(seconds * RATE))
    place(track, thud(0.4, 0.9, 260, 110), 0)
    place(track, band(noise(0.06), 600, 3000) * np.exp(-times(0.06) * 60) * 0.4, 0)
    t = times(0.6)
    freq = 330 + 140 * np.sin(2 * np.pi * 9 * t) * np.exp(-t * 5)
    boing = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 5)
    place(track, boing * 0.45, 0.05)
    write("tag", [mono(track, seconds, wet=0.12, room=0.5, seed=123)])


def make_zap():
    """The Moonbeam Blaster: a falling laser chirp with a sparkle."""
    reseed(124)
    seconds = 0.6
    track = np.zeros(int(seconds * RATE))
    place(track, glide_tone(2400, 300, 0.35, 0.5, "square", 5), 0)
    place(track, glide_tone(3600, 600, 0.3, 0.2, "sine", 4), 0)
    place(track, band(noise(0.25), 5000, 12000) * np.exp(-times(0.25) * 14) * 0.25, 0.02)
    write("zap", [mono(track, seconds, wet=0.15, room=0.6, seed=124)])


def make_misfire():
    """A blaster that zapped the wrong guest: a sputter and a sad buzz."""
    reseed(125)
    seconds = 0.9
    track = np.zeros(int(seconds * RATE))
    for i in range(4):
        place(track, band(noise(0.05), 800, 4000) * np.exp(-times(0.05) * 50) * 0.5, i * 0.07)
    place(track, glide_tone(220, 110, 0.6, 0.35, "saw", 2), 0.28)
    write("misfire", [mono(track, seconds, wet=0.1, room=0.4, seed=125, peak=0.8)])


def make_daze():
    """Knocked dizzy: twinkly stars tumbling down."""
    reseed(126)
    seconds = 1.2
    track = np.zeros(int(seconds * RATE))
    for i, name in enumerate(["E7", "C7", "A6", "F6", "D6", "B5"]):
        place(track, music_box(note(name), 0.5, 0.35), i * 0.08)
    place(track, glide_tone(900, 300, 0.7, 0.15, "sine", 3), 0)
    write("daze", [mono(track, seconds, wet=0.25, room=0.8, seed=126, peak=0.8)])


def make_revive():
    """Back on your feet: a rising shimmer and a warm major chord."""
    reseed(127)
    seconds = 1.6
    track = np.zeros(int(seconds * RATE))
    rise = sweep(noise(0.6), 800, 8000) * np.sin(np.pi * times(0.6) / 0.6) ** 2
    place(track, rise * 0.3, 0)
    for i, name in enumerate(["G5", "B5", "D6", "G6"]):
        place(track, music_box(note(name), 1, 0.35), 0.35 + i * 0.07)
    for name in ("G4", "B4", "D5"):
        place(track, organ(note(name), 1, 0.07, attack=0.1, release=0.6), 0.35)
    write("revive", [mono(track, seconds, wet=0.3, room=1, seed=127, peak=0.8)])


def make_pickup():
    """Picking something up: a quick pop up a fifth."""
    reseed(128)
    seconds = 0.45
    track = np.zeros(int(seconds * RATE))
    place(track, pluck(note("A5"), 0.2, 0.5), 0)
    place(track, pluck(note("E6"), 0.3, 0.5), 0.05)
    write("pickup", [mono(track, seconds, wet=0.12, room=0.4, seed=128, peak=0.75)])


def make_coin():
    """A candy coin: a little two-note ching."""
    reseed(129)
    seconds = 0.6
    track = np.zeros(int(seconds * RATE))
    place(track, music_box(1976, 0.4, 0.5), 0)
    place(track, music_box(2637, 0.5, 0.5), 0.06)
    write("coin", [mono(track, seconds, wet=0.15, room=0.5, seed=129, peak=0.7)])


def make_page():
    """A clue page picked up: a papery rustle and a soft chime."""
    reseed(130)
    seconds = 0.8
    track = np.zeros(int(seconds * RATE))
    for i in range(5):
        place(track, band(noise(0.06), 2000, 8000) * np.exp(-times(0.06) * 40) * 0.35, i * 0.035 + rng.uniform(0, 0.01))
    place(track, music_box(note("D6"), 0.6, 0.35), 0.15)
    place(track, music_box(note("A6"), 0.6, 0.25), 0.22)
    write("page", [mono(track, seconds, wet=0.2, room=0.6, seed=130, peak=0.75)])


def make_torn():
    """A page torn up: a ragged rip sliding down."""
    reseed(131)
    seconds = 0.6
    t = times(0.45)
    grit = 0.5 + 0.5 * np.sign(np.sin(2 * np.pi * 60 * t + rng.uniform(0, 1, len(t)) * 0.8))
    rip = sweep(noise(0.45), 6000, 1200) * grit * np.sin(np.pi * t / 0.45) ** 0.5
    track = np.zeros(int(seconds * RATE))
    place(track, rip * 0.6, 0)
    write("torn", [mono(track, seconds, wet=0.1, room=0.4, seed=131, peak=0.8)])


def make_bell():
    """The Truth Bell ringing: a big, clear toll."""
    reseed(132)
    seconds = 3.5
    track = np.zeros(int(seconds * RATE))
    place(track, bell(note("E4"), 3.5, 0.7), 0)
    place(track, bell(note("E5"), 2.5, 0.25), 0)
    place(track, thud(0.5, 0.4, 120, 60), 0)
    write("bell", [mono(track, seconds, wet=0.35, room=2, seed=132)])


def make_blackout():
    """The lights cut: a click, a hum winding down to nothing."""
    reseed(133)
    seconds = 1.6
    track = np.zeros(int(seconds * RATE))
    place(track, band(noise(0.03), 1000, 6000) * np.exp(-times(0.03) * 120) * 0.8, 0)
    place(track, thud(0.3, 0.6, 160, 60), 0)
    t = times(1.4)
    freq = 120 * np.exp(-t * 1.2) + 20
    hum = sum(np.sin(n * 2 * np.pi * np.cumsum(freq) / RATE) / n for n in (1, 2, 3, 4)) * np.exp(-t * 1.5)
    place(track, hum * 0.4, 0.03)
    write("blackout", [mono(track, seconds, wet=0.3, room=1.2, seed=133)])


def make_tick():
    """The last ten seconds: a dry clock tick."""
    reseed(134)
    seconds = 0.2
    track = np.zeros(int(seconds * RATE))
    place(track, music_box(1250, 0.08, 0.6), 0)
    place(track, band(noise(0.04), 2000, 7000) * np.exp(-times(0.04) * 120) * 0.3, 0)
    write("tick", [normalise(track, 0.7)])


# The plaza ------------------------------------------------------------------------


def make_crate_roll():
    """The crate shuffling: one ratchet click (the game plays it faster and
    higher as it slows)."""
    reseed(140)
    seconds = 0.15
    track = np.zeros(int(seconds * RATE))
    place(track, band(noise(0.03), 1500, 6000) * np.exp(-times(0.03) * 140), 0)
    place(track, music_box(1500, 0.1, 0.3), 0)
    write("crate_roll", [normalise(track, 0.6)])


def make_crate_reveal():
    """What came out of the crate: a burst, a sparkle and a rising chord."""
    reseed(141)
    seconds = 2.2
    track = np.zeros(int(seconds * RATE))
    place(track, thud(0.4, 0.7, 200, 80), 0)
    place(track, band(noise(0.6), 4000, 12000) * np.exp(-times(0.6) * 6) * 0.3, 0)
    for i, name in enumerate(["C5", "G5", "C6", "E6", "G6", "C7"]):
        place(track, music_box(note(name), 1.4, 0.32), 0.05 + i * 0.06)
    for name in ("C4", "E4", "G4"):
        place(track, organ(note(name), 1.4, 0.07, attack=0.03, release=0.8), 0.05)
    write("crate_reveal", [mono(track, seconds, wet=0.3, room=1.2, seed=141)])


def make_trade_done():
    """A trade going through: two chimes passing each other and a ching."""
    reseed(142)
    seconds = 1.4
    track = np.zeros(int(seconds * RATE))
    for i, (a, b) in enumerate((("E5", "C6"), ("G5", "A5"), ("C6", "E5"))):
        place(track, music_box(note(a), 0.6, 0.3), i * 0.1)
        place(track, music_box(note(b), 0.6, 0.3), i * 0.1 + 0.03)
    place(track, music_box(2093, 0.8, 0.45), 0.38)
    place(track, music_box(3136, 0.7, 0.25), 0.38)
    write("trade_done", [mono(track, seconds, wet=0.25, room=0.8, seed=142, peak=0.8)])


def make_level_up():
    """A new level: a quick climb and a bright landing."""
    reseed(143)
    seconds = 1.8
    track = np.zeros(int(seconds * RATE))
    for i, name in enumerate(["C5", "D5", "E5", "G5", "C6"]):
        place(track, square_lead(note(name), 0.09, 0.22), i * 0.08)
    place(track, square_lead(note("E6"), 0.5, 0.2), 0.4)
    place(track, bell(note("C6"), 1.4, 0.25), 0.4)
    for name in ("C4", "G4", "E5"):
        place(track, organ(note(name), 1.1, 0.06, attack=0.02, release=0.7), 0.4)
    write("level_up", [mono(track, seconds, wet=0.25, room=1, seed=143, peak=0.8)])


def make_click():
    """A menu button: a soft, short tick."""
    reseed(144)
    seconds = 0.12
    track = np.zeros(int(seconds * RATE))
    place(track, pluck(1400, 0.08, 0.5), 0)
    place(track, band(noise(0.02), 2000, 8000) * np.exp(-times(0.02) * 200) * 0.2, 0)
    write("click", [normalise(track, 0.5)])


def make_deny():
    """Not yet: two soft, low wooden knocks, the second one lower."""
    reseed(145)
    seconds = 0.7
    track = np.zeros(int(seconds * RATE))
    for at, name in ((0, "A3"), (0.16, "E3")):
        place(track, thud(0.25, 0.5, 220, 120), at)
        place(track, music_box(note(name), 0.35, 0.5), at)
        place(track, band(noise(0.05), 400, 1800) * np.exp(-times(0.05) * 60) * 0.3, at)
    write("deny", [mono(track, seconds, wet=0.15, room=0.5, seed=145, peak=0.6)])


def make_vote():
    """A map vote: a round bubbly blip."""
    reseed(146)
    seconds = 0.35
    track = np.zeros(int(seconds * RATE))
    place(track, glide_tone(500, 900, 0.18, 0.5, "sine", 3), 0)
    place(track, music_box(1800, 0.25, 0.2), 0.08)
    write("vote", [mono(track, seconds, wet=0.1, room=0.3, seed=146, peak=0.6)])


def make_fanfare():
    """A party horn and a little cheer of bells, for the party emotes."""
    reseed(147)
    seconds = 1.5
    track = np.zeros(int(seconds * RATE))
    t = times(0.6)
    freq = 520 + 260 * np.minimum(1, t / 0.15)
    horn = sum(np.sin(n * 2 * np.pi * np.cumsum(freq) / RATE) / n for n in range(1, 8))
    horn *= np.minimum(1, t / 0.02) * np.clip((0.6 - t) / 0.1, 0, 1)
    place(track, band(horn, 300, 5000) * 0.4, 0)
    for i, name in enumerate(["G5", "C6", "E6", "G6"]):
        place(track, music_box(note(name), 0.8, 0.25), 0.45 + i * 0.07)
    write("fanfare", [mono(track, seconds, wet=0.2, room=0.8, seed=147, peak=0.75)])


def make_pop():
    """A confetti popper: a sharp pop and a papery spray."""
    reseed(148)
    seconds = 0.9
    track = np.zeros(int(seconds * RATE))
    place(track, band(noise(0.04), 300, 5000) * np.exp(-times(0.04) * 90), 0)
    place(track, thud(0.2, 0.6, 300, 120), 0)
    spray = band(noise(0.7), 3000, 11000) * np.exp(-times(0.7) * 5) * 0.2
    place(track, spray, 0.03)
    write("pop", [mono(track, seconds, wet=0.15, room=0.5, seed=148, peak=0.75)])


MAKERS = {
    "music_lobby": make_lobby_music,
    "music_round": make_round_music,
    "music_final": make_final_music,
    "ambience_manor": make_manor_ambience,
    "ambience_carnival": make_carnival_ambience,
    "reveal_shadow": make_reveal_shadow,
    "reveal_guest": make_reveal_guest,
    "win_guests": make_win_guests,
    "win_phantom": make_win_phantom,
    "draw": make_draw,
    "swing": make_swing,
    "throw": make_throw,
    "tag": make_tag,
    "zap": make_zap,
    "misfire": make_misfire,
    "daze": make_daze,
    "revive": make_revive,
    "pickup": make_pickup,
    "coin": make_coin,
    "page": make_page,
    "torn": make_torn,
    "bell": make_bell,
    "blackout": make_blackout,
    "tick": make_tick,
    "crate_roll": make_crate_roll,
    "crate_reveal": make_crate_reveal,
    "trade_done": make_trade_done,
    "level_up": make_level_up,
    "click": make_click,
    "deny": make_deny,
    "vote": make_vote,
    "fanfare": make_fanfare,
    "pop": make_pop,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(MAKERS)
    for name in wanted:
        MAKERS[name]()
