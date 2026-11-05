"""Makes Catwalk Clash's original music and sound effects from scratch.

Every sound is synthesised here from sine waves and noise, so the project
owns all of it outright: three songs (the lobby, backstage and the runway),
a crowd loop and the effects. The melodies were written for this game; none
is a cover, remix or soundalike of an existing song. Run it with Python 3
and numpy, with ffmpeg on the path for OGG encoding, from the game folder:

    python3 tools/make_sounds.py

It writes assets/audio/*.ogg, named as in src/shared/Config/Sounds.luau.
Upload those to Roblox and paste their asset ids into that file
(docs/launch.md, step 5).
"""

import os
import subprocess

import numpy as np

RATE = 44100
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(2026)


def times(seconds):
    return np.arange(int(seconds * RATE)) / RATE


def reseed(seed):
    """Gives each sound its own random sequence, so changing one sound
    doesn't change the others."""
    global rng
    rng = np.random.default_rng(seed)


def noise(seconds):
    return rng.standard_normal(int(seconds * RATE))


STEPS = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi_of(name):
    semitone = STEPS[name[0]]
    rest = name[1:]
    if rest.startswith("b"):
        semitone -= 1
        rest = rest[1:]
    elif rest.startswith("#"):
        semitone += 1
        rest = rest[1:]
    return 12 * (int(rest) + 1) + semitone


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12)


def note(name):
    return hz(midi_of(name))


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


def reverb(signal, seconds=1.6, wet=0.25, seed=0):
    """Convolves with a burst of decaying noise, for a bright hall."""
    local = np.random.default_rng(seed)
    t = times(seconds)
    impulse = local.standard_normal(len(t)) * np.exp(-t * 4)
    impulse = band(impulse, 200, 9000)
    impulse /= np.sqrt(np.sum(impulse**2))
    size = len(signal) + len(impulse)
    wet_signal = np.fft.irfft(np.fft.rfft(signal, size) * np.fft.rfft(impulse, size), size)
    dry = np.concatenate([signal, np.zeros(len(impulse))])
    return dry * (1 - wet) + wet_signal * wet * 3


def place(track, sound, at):
    start = int(at * RATE)
    if start < 0:
        sound, start = sound[-start:], 0
    end = min(len(track), start + len(sound))
    if end > start:
        track[start:end] += sound[: end - start]


def loop(track, length):
    """Folds everything past length back onto the start, so it loops cleanly."""
    samples = int(length * RATE)
    out = track[:samples].copy()
    tail = track[samples:]
    out[: len(tail)] += tail[:samples]
    return out


def normalise(signal, peak=0.89):
    return signal * peak / max(np.max(np.abs(signal)), 1e-9)


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


# Instruments ---------------------------------------------------------------


def kick(amp=1.0):
    t = times(0.4)
    freq = 50 + 120 * np.exp(-t * 30)
    body = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.exp(-t * 8)
    click = band(noise(0.4), 1500, 7000) * np.exp(-t * 140) * 0.3
    return amp * (body + click) * np.minimum(1, t / 0.001)


def snare(amp=1.0):
    t = times(0.28)
    tone = np.sin(2 * np.pi * 200 * t) * np.exp(-t * 30) * 0.5
    return amp * (tone + band(noise(0.28), 1500, 10000) * np.exp(-t * 18))


def clap(amp=1.0):
    t = times(0.32)
    shape = sum(np.where(t >= d, np.exp(-(t - d) * 90), 0) for d in (0, 0.01, 0.021))
    shape = shape + np.where(t >= 0.03, np.exp(-(t - 0.03) * 16) * 0.6, 0)
    return amp * band(noise(0.32), 1000, 7000) * shape


def snap(amp=1.0):
    t = times(0.12)
    return amp * band(noise(0.12), 2000, 9000) * np.exp(-t * 60)


def hat(amp=1.0, open_hat=False):
    seconds = 0.3 if open_hat else 0.07
    t = times(seconds)
    return amp * band(noise(seconds), 7500, 17000) * np.exp(-t * (12 if open_hat else 75))


def crash(amp=1.0):
    t = times(2.0)
    return amp * band(noise(2.0), 3000, 16000) * np.exp(-t * 2.2)


def saw(freq, seconds, amp=1.0, cutoff=900, attack=0.004, decay=6.0, sustain=0.6):
    """A saw wave with its top rolled off: bass and brassy stabs."""
    t = times(seconds + 0.05)
    out = np.zeros_like(t)
    harmonic = 1
    while freq * harmonic < 9000:
        out += np.sin(2 * np.pi * freq * harmonic * t) / harmonic / (1 + (freq * harmonic / cutoff) ** 2)
        harmonic += 1
    shape = np.minimum(1, t / attack) * (sustain + (1 - sustain) * np.exp(-t * decay))
    return amp * out * shape * np.clip((seconds + 0.05 - t) / 0.05, 0, 1)


def supersaw(freq, seconds, amp=1.0, cutoff=2500):
    """Three detuned saws: the bright chord stab of dance pop."""
    total = sum(saw(freq * d, seconds, 1.0, cutoff, decay=5, sustain=0.5) for d in (0.994, 1.0, 1.006))
    return amp * total / 3


def pluck(freq, seconds, amp=1.0):
    t = times(seconds)
    out = sum(np.sin(2 * np.pi * freq * n * t) * np.exp(-t * (6 + n * 2)) / n for n in range(1, 9))
    return amp * out * np.minimum(1, t / 0.002)


def marimba(freq, seconds, amp=1.0):
    """A wooden bar: a fundamental and a high fourth partial, both quick."""
    t = times(seconds)
    out = np.sin(2 * np.pi * freq * t) * np.exp(-t * 5) + 0.25 * np.sin(2 * np.pi * freq * 4 * t) * np.exp(-t * 18)
    return amp * out * np.minimum(1, t / 0.002)


def bell(freq, seconds, amp=1.0):
    t = times(seconds)
    partials = [(1, 1.0, 2.2), (2.76, 0.35, 5), (5.4, 0.15, 9), (8.93, 0.06, 14)]
    sound = sum(level * np.sin(2 * np.pi * freq * r * t) * np.exp(-t * d) for r, level, d in partials)
    return amp * sound * np.minimum(1, t / 0.002)


def soft_lead(freq, seconds, amp=1.0):
    """A round, slightly hollow lead with vibrato that creeps in."""
    t = times(seconds + 0.06)
    wobble = 1 + 0.004 * np.sin(2 * np.pi * 5.5 * t) * np.minimum(1, t / 0.25)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / RATE
    out = np.sin(phase) + 0.35 * np.sin(2 * phase) + 0.18 * np.sin(3 * phase) + 0.08 * np.sin(5 * phase)
    shape = np.minimum(1, t / 0.012) * (0.75 + 0.25 * np.exp(-t * 5))
    return amp * out * shape * np.clip((seconds + 0.06 - t) / 0.06, 0, 1)


def pad(freq, seconds, amp=1.0):
    t = times(seconds)
    out = sum(np.sin(2 * np.pi * freq * d * t) for d in (0.997, 1.0, 1.003)) + 0.3 * np.sin(4 * np.pi * freq * t)
    shape = np.minimum(1, t / 0.4) * np.minimum(1, (seconds - t) / 0.5)
    return amp * out * np.clip(shape, 0, 1) / 3


CHORDS = {
    "C": (0, 4, 7),
    "Dm": (2, 5, 9),
    "Em": (4, 7, 11),
    "F": (5, 9, 0),
    "G": (7, 11, 2),
    "Am": (9, 0, 4),
    "Bb": (10, 2, 5),
    "E": (4, 8, 11),
}


def voicing(chord, low):
    return sorted(low + (pc - low) % 12 for pc in CHORDS[chord])


def root_of(chord, low=28):
    return low + (CHORDS[chord][0] - low) % 12


class Song:
    """Places sounds on stereo buses, then mixes them into a seamless loop."""

    BUSES = ("drums", "bass", "keys", "lead", "sparkle")

    def __init__(self, bpm, bars):
        self.beat = 60 / bpm
        self.bar = self.beat * 4
        self.length = bars * self.bar
        samples = int((self.length + 5) * RATE)
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

    def melody(self, bus, phrase, first_bar, instrument, amp, pan=0.0):
        at = self.at(first_bar)
        for bar_notes in phrase:
            for name, beats in bar_notes:
                if name:
                    self.add(bus, instrument(note(name), beats * self.beat * 0.92, amp), at, pan)
                at += beats * self.beat

    def mix(self, name, pump=0.5):
        duck = np.ones(self.buses["bass"].shape[1])
        for at in self.kicks:
            start = int(at * RATE)
            t = times(0.3)
            end = min(len(duck), start + len(t))
            duck[start:end] *= 1 - pump * np.exp(-t[: end - start] / 0.09)
        self.buses["bass"] *= duck
        self.buses["keys"] *= duck

        lead = self.buses["lead"]
        gap = int(self.beat * 0.75 * RATE)
        echo = np.zeros_like(lead)
        echo[0, gap:] += lead[1, :-gap] * 0.25
        echo[1, gap:] += lead[0, :-gap] * 0.25
        self.buses["lead"] = lead + echo

        rooms = {"drums": 0.08, "bass": 0.0, "keys": 0.22, "lead": 0.25, "sparkle": 0.4}
        channels = []
        for side in (0, 1):
            total = np.zeros(int(self.length * RATE))
            for bus, wet in rooms.items():
                signal = self.buses[bus][side]
                if wet > 0:
                    signal = reverb(signal, seconds=1.6, wet=wet, seed=side * 10 + len(bus))
                total += loop(signal, self.length)
            channels.append(total)
        peak = max(np.max(np.abs(c)) for c in channels)
        channels = [np.tanh(c / peak * 1.25) / np.tanh(1.25) * 0.82 for c in channels]
        write(name, channels)


def chords_for(sections, progressions):
    """The chord for every bar, from each section's progression."""
    bars = []
    for section, count in sections:
        prog = progressions[section]
        bars += [(section, prog[i % len(prog)], i) for i in range(count)]
    return bars


# Songs ---------------------------------------------------------------------


def make_lobby():
    """Glow Plaza: C major at 112 bpm, bright and easy, for hanging out."""
    reseed(1)
    sections = [("intro", 4), ("verse", 8), ("chorus", 8), ("break", 4), ("chorus2", 8)]
    song = Song(112, 32)
    progressions = {
        "intro": ["C", "G", "Am", "F"],
        "verse": ["C", "G", "Am", "F"],
        "chorus": ["F", "G", "Em", "Am", "F", "G", "C", "C"],
        "break": ["Am", "F", "C", "G"],
        "chorus2": ["F", "G", "Em", "Am", "F", "G", "C", "C"],
    }
    for bar, (section, chord, i) in enumerate(chords_for(sections, progressions)):
        root = root_of(chord)
        # Drums: a light pop beat, fuller in the choruses.
        if section != "intro" or i >= 2:
            for b in (0, 2):
                song.kick(song.at(bar, b), 0.75)
            song.kick(song.at(bar, 2.5), 0.45) if section.startswith("chorus") else None
            for b in (1, 3):
                song.add("drums", snap(0.45), song.at(bar, b), 0.1)
                if section.startswith("chorus"):
                    song.add("drums", clap(0.3), song.at(bar, b), -0.1)
        for eighth in range(8):
            song.add("drums", hat(0.12 + 0.06 * (eighth % 2)), song.at(bar, eighth / 2), 0.35)
        if section.startswith("chorus") and i == 0:
            song.add("drums", crash(0.25), song.at(bar), -0.2)
        # Bass: root and fifth.
        if section != "intro":
            for b, offset in ((0, 0), (1.5, 7), (2, 0), (3, 12)):
                song.add("bass", saw(hz(root + offset), song.beat * 0.8, 0.32, cutoff=500), song.at(bar, b))
        # Keys: plucked chords on the offbeats and a soft pad.
        for m in voicing(chord, 55):
            song.add("keys", pad(hz(m), song.bar + 0.3, 0.05), song.at(bar), -0.25)
        for b in (0.5, 1.5, 2.5, 3.5):
            for m in voicing(chord, 60):
                song.add("keys", pluck(hz(m), song.beat * 0.6, 0.06), song.at(bar, b), 0.3)
        # Sparkle: a bell arpeggio in the intro and break.
        if section in ("intro", "break"):
            tones = voicing(chord, 72)
            for k in range(4):
                song.add("sparkle", bell(hz(tones[k % 3] + (12 if k == 3 else 0)), 1.4, 0.16), song.at(bar, k), 0.5)

    verse = [
        [("E5", 1), ("G5", 0.5), ("E5", 0.5), ("D5", 1), ("C5", 1)],
        [("D5", 1.5), ("B4", 0.5), ("G4", 2)],
        [("C5", 0.5), ("E5", 0.5), ("A5", 1), ("G5", 0.5), ("E5", 0.5), ("C5", 1)],
        [("A4", 1), ("C5", 1), ("F5", 2)],
        [("E5", 1), ("G5", 0.5), ("E5", 0.5), ("D5", 1), ("C5", 1)],
        [("D5", 1), ("G5", 1), ("B5", 2)],
        [("A5", 0.5), ("G5", 0.5), ("E5", 1), ("C5", 0.5), ("D5", 0.5), ("E5", 1)],
        [("F5", 1.5), ("E5", 0.5), ("D5", 2)],
    ]
    chorus = [
        [("A5", 0.5), ("C6", 0.5), ("C6", 1), ("A5", 0.5), ("G5", 0.5), ("F5", 1)],
        [("G5", 0.5), ("B5", 0.5), ("D6", 1), ("B5", 1), ("G5", 1)],
        [("G5", 0.5), ("B5", 0.5), ("E6", 1), ("D6", 0.5), ("B5", 0.5), ("G5", 1)],
        [("A5", 1.5), ("E5", 0.5), ("C6", 2)],
        [("A5", 0.5), ("C6", 0.5), ("F6", 1), ("E6", 0.5), ("C6", 0.5), ("A5", 1)],
        [("B5", 0.5), ("D6", 0.5), ("G6", 1), ("F6", 0.5), ("D6", 0.5), ("B5", 1)],
        [("C6", 1), ("E6", 0.5), ("D6", 0.5), ("C6", 1), ("G5", 1)],
        [("C6", 3), (None, 1)],
    ]
    breakdown = [[("E6", 2), ("C6", 2)], [("A5", 2), ("C6", 2)], [("G5", 2), ("E5", 2)], [("D5", 2), ("G5", 2)]]
    song.melody("lead", verse, 4, soft_lead, 0.2)
    song.melody("lead", chorus, 12, soft_lead, 0.24)
    song.melody("sparkle", chorus, 12, bell, 0.1, -0.4)
    song.melody("lead", breakdown, 20, soft_lead, 0.16)
    song.melody("lead", chorus, 24, soft_lead, 0.26)
    song.melody("sparkle", chorus, 24, bell, 0.12, -0.4)
    song.mix("music_lobby", pump=0.35)


def make_backstage():
    """Dressing Room Shuffle: F major at 100 bpm, a playful bounce on
    marimba and plucked bass, for picking outfits against the clock."""
    reseed(2)
    sections = [("intro", 4), ("a", 8), ("b", 8), ("a2", 8), ("outro", 4)]
    song = Song(100, 32)
    progressions = {
        "intro": ["F", "Dm", "Bb", "C"],
        "a": ["F", "Dm", "Bb", "C"],
        "b": ["Bb", "C", "Am", "Dm", "Bb", "C", "F", "F"],
        "a2": ["F", "Dm", "Bb", "C"],
        "outro": ["Bb", "C", "F", "F"],
    }
    for bar, (section, chord, i) in enumerate(chords_for(sections, progressions)):
        root = root_of(chord, 36)
        if section != "intro":
            song.kick(song.at(bar, 0), 0.8)
            song.kick(song.at(bar, 1.75), 0.5)
            song.kick(song.at(bar, 2.5), 0.6)
        for b in (1, 3):
            song.add("drums", snap(0.5), song.at(bar, b), 0.15)
            if section in ("b", "a2"):
                song.add("drums", clap(0.25), song.at(bar, b), -0.1)
        for sixteenth in range(16):
            # A shuffled hat: the second of each pair a little late.
            late = 0.08 if sixteenth % 2 else 0
            song.add("drums", hat(0.1 if sixteenth % 4 else 0.16), song.at(bar, sixteenth / 4 + late), 0.4)
        for b, offset in ((0, 0), (1, 12), (2, 7), (3, 12)):
            song.add("bass", pluck(hz(root + offset), song.beat * 0.9, 0.5), song.at(bar, b))
        for b in (0.5, 1.5, 2.5, 3.5):
            for m in voicing(chord, 62):
                song.add("keys", marimba(hz(m), song.beat, 0.05), song.at(bar, b), -0.35)

    tune_a = [
        [("A5", 0.5), ("C6", 0.5), ("A5", 0.5), ("F5", 0.5), ("G5", 1), ("A5", 1)],
        [("F5", 0.5), ("D5", 0.5), ("F5", 1), ("A5", 1), (None, 1)],
        [("Bb5", 0.5), ("A5", 0.5), ("G5", 0.5), ("F5", 0.5), ("D5", 1), ("F5", 1)],
        [("E5", 0.5), ("G5", 0.5), ("C6", 1), ("Bb5", 0.5), ("G5", 0.5), ("E5", 1)],
        [("A5", 0.5), ("C6", 0.5), ("A5", 0.5), ("F5", 0.5), ("G5", 1), ("A5", 1)],
        [("D6", 1), ("C6", 0.5), ("A5", 0.5), ("F5", 2)],
        [("D5", 0.5), ("F5", 0.5), ("Bb5", 1), ("A5", 0.5), ("G5", 0.5), ("F5", 1)],
        [("G5", 1.5), ("E5", 0.5), ("C5", 2)],
    ]
    tune_b = [
        [("D6", 1), ("Bb5", 1), ("F5", 2)],
        [("E6", 1), ("C6", 1), ("G5", 2)],
        [("C6", 0.5), ("A5", 0.5), ("E5", 1), ("A5", 1), ("C6", 1)],
        [("D6", 1.5), ("C6", 0.5), ("A5", 2)],
        [("D6", 0.5), ("F6", 0.5), ("D6", 1), ("Bb5", 1), ("F5", 1)],
        [("E6", 0.5), ("G6", 0.5), ("E6", 1), ("C6", 1), ("G5", 1)],
        [("F6", 1), ("E6", 0.5), ("C6", 0.5), ("A5", 1), ("C6", 1)],
        [("F6", 3), (None, 1)],
    ]
    song.melody("lead", tune_a, 4, marimba, 0.32, 0.1)
    song.melody("lead", tune_b, 12, pluck, 0.22, -0.1)
    song.melody("sparkle", tune_b, 12, bell, 0.08, 0.4)
    song.melody("lead", tune_a, 20, marimba, 0.34, 0.1)
    song.melody("sparkle", tune_a, 20, bell, 0.07, -0.4)
    song.mix("music_backstage", pump=0.3)


def make_runway():
    """Strut: A minor at 126 bpm, a four-on-the-floor runway track with a
    pumping bass, supersaw stabs and a big hook."""
    reseed(3)
    sections = [("intro", 4), ("build", 4), ("drop", 8), ("verse", 8), ("drop2", 8)]
    song = Song(126, 32)
    progressions = {
        "intro": ["Am", "F", "C", "G"],
        "build": ["Am", "F", "C", "G"],
        "drop": ["Am", "F", "C", "G"],
        "verse": ["Dm", "Am", "F", "E"],
        "drop2": ["Am", "F", "C", "G"],
    }
    for bar, (section, chord, i) in enumerate(chords_for(sections, progressions)):
        root = root_of(chord)
        drop = section.startswith("drop")
        if section != "intro":
            for b in range(4):
                song.kick(song.at(bar, b), 0.95)
        for b in (1, 3):
            if section != "intro":
                song.add("drums", clap(0.45 if drop else 0.3), song.at(bar, b), 0.05)
        for eighth in range(8):
            offbeat = eighth % 2 == 1
            song.add("drums", hat(0.22 if offbeat else 0.1, open_hat=drop and offbeat), song.at(bar, eighth / 2), 0.3)
        if drop:
            for sixteenth in range(16):
                song.add("drums", hat(0.06), song.at(bar, sixteenth / 4 + 0.125), -0.4)
            if i == 0:
                song.add("drums", crash(0.35), song.at(bar), -0.2)
        if section == "build":
            hits = 4 * (i + 1)
            for h in range(hits):
                song.add("drums", snare(0.12 + 0.08 * i), song.at(bar, h * 4 / hits), 0.1)
            if i == 2:
                riser = sweep(noise(song.bar * 2), 400, 9000) * np.linspace(0, 1, int(song.bar * 2 * RATE)) ** 2
                song.add("drums", riser * 0.22, song.at(bar))
        # Bass on the offbeats, house style.
        if section != "intro":
            for b in (0.5, 1.5, 2.5, 3.5):
                song.add("bass", saw(hz(root), song.beat * 0.45, 0.38, cutoff=600 if drop else 400), song.at(bar, b))
        # Keys: supersaw stabs in the drops, a pad elsewhere.
        if drop:
            for b in (0, 0.75, 1.5, 2.5, 3.25):
                for m in voicing(chord, 57):
                    song.add("keys", supersaw(hz(m), song.beat * 0.35, 0.05), song.at(bar, b), -0.2)
        else:
            for m in voicing(chord, 57):
                song.add("keys", pad(hz(m), song.bar + 0.3, 0.06), song.at(bar), -0.2)
            if section == "intro" or section == "verse":
                tones = voicing(chord, 69)
                for s in range(8):
                    song.add("keys", pluck(hz(tones[s % 3] + (12 if s % 4 == 3 else 0)), song.beat * 0.4, 0.07), song.at(bar, s / 2), 0.4)

    hook = [
        [("E5", 0.5), ("A5", 0.5), ("C6", 0.5), ("B5", 0.5), ("A5", 1), ("E5", 1)],
        [("F5", 0.5), ("A5", 0.5), ("C6", 0.5), ("D6", 0.5), ("C6", 1), ("A5", 1)],
        [("G5", 0.5), ("C6", 0.5), ("E6", 0.5), ("D6", 0.5), ("C6", 1), ("G5", 1)],
        [("B5", 0.5), ("D6", 0.5), ("B5", 0.5), ("G5", 0.5), ("A5", 2)],
    ]
    verse = [
        [("D5", 1), ("F5", 1), ("A5", 1.5), ("G5", 0.5)],
        [("E5", 1), ("C5", 1), ("E5", 2)],
        [("F5", 1), ("A5", 1), ("C6", 1.5), ("B5", 0.5)],
        [("G#5", 2), ("B5", 1), ("E5", 1)],
    ]
    song.melody("lead", hook, 4, soft_lead, 0.12)
    song.melody("lead", hook + hook, 8, supersaw, 0.2)
    song.melody("sparkle", hook + hook, 8, bell, 0.08, 0.4)
    song.melody("lead", verse + verse, 16, soft_lead, 0.22)
    song.melody("lead", hook + hook, 24, supersaw, 0.22)
    song.melody("sparkle", hook + hook, 24, bell, 0.1, -0.4)
    song.mix("music_runway", pump=0.55)


def whoo(seconds, amp=1.0):
    """One person cheering 'whoo!': a voice-like glide up and down."""
    t = times(seconds)
    start = rng.uniform(300, 600)
    peak = start * rng.uniform(1.3, 1.8)
    curve = start + (peak - start) * np.sin(np.pi * np.minimum(t / seconds, 1)) ** 0.7
    phase = 2 * np.pi * np.cumsum(curve) / RATE
    tone = np.sin(phase) + 0.5 * np.sin(2 * phase) + 0.3 * np.sin(3 * phase) + 0.15 * np.sin(4 * phase)
    breath = band(noise(seconds), 800, 4000) * 0.3
    shape = np.sin(np.pi * np.minimum(t / seconds, 1))
    return amp * (tone + breath) * shape


def make_crowd():
    """A fashion-show crowd: chatter, applause swells and the odd whoop."""
    reseed(4)
    length = 12.0
    track = np.zeros(int((length + 3) * RATE))
    chatter = band(noise(length + 3), 250, 2500)
    wobble = 0.6 + 0.4 * np.abs(np.sin(2 * np.pi * 0.21 * times(length + 3)))
    track += chatter * wobble * 0.25
    for _ in range(140):
        place(track, clap(rng.uniform(0.05, 0.12)), rng.uniform(0, length))
    for _ in range(6):
        place(track, whoo(rng.uniform(0.5, 0.9), 0.12), rng.uniform(0, length))
    out = loop(track, length)
    write("crowd_loop", [normalise(out, 0.7), normalise(np.roll(out, int(0.37 * RATE)), 0.7)])


# Effects -------------------------------------------------------------------


def mono(name, track, peak=0.8, room=0.2, seed=0):
    signal = reverb(track, seconds=0.9, wet=room, seed=seed)[: len(track)] if room > 0 else track
    write(name, [normalise(signal, peak)])


def make_effects():
    reseed(10)
    t = times(0.05)
    mono("click", np.sin(2 * np.pi * 1800 * t) * np.exp(-t * 120) + band(noise(0.05), 3000, 9000) * np.exp(-t * 200) * 0.3, 0.5, 0)

    track = np.zeros(int(0.35 * RATE))
    place(track, band(noise(0.25), 1500, 8000) * np.exp(-times(0.25) * 16) * 0.4, 0)
    place(track, pluck(note("A5"), 0.3, 0.6), 0.03)
    mono("equip", track, 0.6, 0.15, 1)

    track = np.zeros(int(0.9 * RATE))
    for k, name in enumerate(["E6", "G#6", "B6", "E7"]):
        place(track, bell(note(name), 0.7, 0.5), k * 0.06)
    mono("purchase", track, 0.75, 0.25, 2)

    track = np.zeros(int(0.4 * RATE))
    for k, freq in enumerate((330, 247)):
        tt = times(0.15)
        place(track, np.sin(2 * np.pi * freq * tt) * np.exp(-tt * 14) + 0.3 * np.sin(4 * np.pi * freq * tt) * np.exp(-tt * 20), k * 0.14)
    mono("deny", track, 0.6, 0.05, 3)

    track = np.zeros(int(2.0 * RATE))
    riser = sweep(noise(0.9), 300, 7000) * np.linspace(0, 1, int(0.9 * RATE)) ** 2
    place(track, riser * 0.6, 0)
    place(track, kick(0.9), 0.9)
    for m in voicing("C", 72):
        place(track, bell(hz(m), 1.1, 0.35), 0.9)
    place(track, crash(0.25), 0.9)
    mono("theme_reveal", track, 0.85, 0.3, 4)

    tt = times(0.08)
    mono("tick", (np.sin(2 * np.pi * 1200 * tt) + 0.4 * np.sin(2 * np.pi * 2600 * tt)) * np.exp(-tt * 70), 0.5, 0)

    track = sweep(noise(0.6), 500, 4000) * np.sin(np.pi * np.linspace(0, 1, int(0.6 * RATE)))
    mono("whoosh", track, 0.6, 0.15, 5)

    track = np.zeros(int(0.35 * RATE))
    tt = times(0.25)
    place(track, np.sin(2 * np.pi * (500 + 500 * tt / 0.25) * tt) * np.exp(-tt * 18), 0)
    place(track, pluck(note("C6"), 0.25, 0.5), 0.02)
    mono("vote", track, 0.6, 0.1, 6)

    track = np.zeros(int(1.4 * RATE))
    for h in range(14):
        place(track, snare(0.2 + h * 0.03), h * 0.045)
    place(track, crash(0.3), 0.65)
    for m in voicing("G", 67):
        place(track, bell(hz(m), 0.8, 0.35), 0.65)
    mono("vote_reveal", track, 0.8, 0.25, 7)

    track = np.zeros(int(1.4 * RATE))
    for k, name in enumerate(["C5", "E5", "G5"]):
        place(track, saw(note(name), 0.18, 0.35, cutoff=1800), k * 0.12)
    for m in voicing("C", 60) + [72]:
        place(track, saw(hz(m), 0.7, 0.25, cutoff=2200, decay=2), 0.36)
    place(track, bell(note("C7"), 0.9, 0.2), 0.36)
    mono("match_win", track, 0.8, 0.25, 8)

    track = np.zeros(int(3.0 * RATE))
    fanfare = [("G4", 0, 0.15), ("C5", 0.15, 0.15), ("E5", 0.3, 0.15), ("G5", 0.45, 0.5)]
    for name, at, seconds in fanfare:
        place(track, saw(note(name), seconds, 0.35, cutoff=2000), at)
    for m in voicing("C", 55) + voicing("C", 67) + [84]:
        place(track, saw(hz(m), 1.6, 0.16, cutoff=2400, decay=1.2, sustain=0.5), 0.95)
    for k, name in enumerate(["C7", "E7", "G7", "C8"]):
        place(track, bell(note(name), 1.2, 0.18), 0.95 + k * 0.08)
    place(track, crash(0.4), 0.95)
    place(track, kick(1.0), 0.95)
    mono("crown", track, 0.85, 0.35, 9)

    reseed(11)
    track = np.zeros(int(3.0 * RATE))
    swell = band(noise(3.0), 300, 5000) * np.sin(np.pi * np.minimum(times(3.0) / 3.0, 1)) ** 0.5 * 0.35
    track += swell
    for _ in range(90):
        place(track, clap(rng.uniform(0.08, 0.2)), rng.uniform(0, 2.4))
    for _ in range(9):
        place(track, whoo(rng.uniform(0.5, 0.9), 0.18), rng.uniform(0, 1.8))
    mono("cheer", track, 0.8, 0.2, 10)

    reseed(12)
    track = np.zeros(int(0.25 * RATE))
    tt = times(0.03)
    place(track, band(noise(0.03), 2000, 9000) * np.exp(-tt * 100), 0)
    place(track, band(noise(0.06), 800, 5000) * np.exp(-times(0.06) * 60) * 0.6, 0.05)
    place(track, band(noise(0.03), 2000, 9000) * np.exp(-tt * 100) * 0.7, 0.12)
    mono("shutter", track, 0.6, 0.05, 11)

    track = np.zeros(int(0.9 * RATE))
    for k, name in enumerate(["C7", "E7", "G7", "B7", "D8"]):
        place(track, bell(note(name), 0.5, 0.3), k * 0.045)
    mono("sparkle", track, 0.55, 0.3, 12)

    track = np.zeros(int(1.6 * RATE))
    for k, name in enumerate(["C5", "E5", "G5", "C6", "E6"]):
        place(track, marimba(note(name), 0.6, 0.5), k * 0.07)
        place(track, bell(note(name) * 2, 0.8, 0.2), k * 0.07)
    for m in voicing("C", 72):
        place(track, pad(hz(m), 1.1, 0.25), 0.35)
    mono("level_up", track, 0.75, 0.3, 13)

    track = np.zeros(int(0.7 * RATE))
    place(track, pluck(note("G5"), 0.25, 0.6), 0)
    place(track, pluck(note("C6"), 0.5, 0.7), 0.12)
    place(track, bell(note("C7"), 0.5, 0.25), 0.12)
    mono("ready", track, 0.7, 0.2, 14)


if __name__ == "__main__":
    make_lobby()
    make_backstage()
    make_runway()
    make_crowd()
    make_effects()
