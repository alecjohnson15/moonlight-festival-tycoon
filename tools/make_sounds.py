"""Makes the Moonlight Festival's original sounds and music from scratch.

Every sound is synthesised here from sine waves and noise, so the project
owns all of it outright. Run it with Python 3 and numpy, with ffmpeg on the
path for OGG encoding:

    python3 tools/make_sounds.py

It writes assets/audio/*.ogg. Upload those to Roblox and paste their asset
ids into Sounds in the theme pack (see the README).
"""

import os
import subprocess

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


# The music: two original, upbeat Halloween songs with a pop shape (a hooky
# chorus over a four-chord loop, four-on-the-floor drums and a pumping bass),
# dressed in spooky sounds: a gliding theremin, a haunted-house organ,
# harpsichord, bells and a heartbeat. Both melodies were written for this
# project; neither is a cover, remix or soundalike of any existing song.

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


def make_music():
    """Moonlit Mischief: A minor at 124 bpm, sung by a theremin."""
    reseed(1)
    make_song(
        "music",
        124,
        "theremin",
        {
            "intro": ["Am", "F", "C", "G"],
            "verse": ["Am", "F", "C", "G"],
            "pre": ["Dm", "Dm", "E", "E"],
            "chorus": ["Am", "F", "C", "E"],
            "break": ["Am", "Am", "F", "E"],
            "hook": ["Am", "F", "C", "E"],
        },
        {
            "verse": [
                [(None, 1), ("E5", 0.5), ("E5", 0.5), ("D5", 0.5), ("C5", 0.5), ("D5", 1)],
                [("C5", 1.5), ("A4", 0.5), ("A4", 1), (None, 1)],
                [(None, 1), ("G4", 0.5), ("C5", 0.5), ("E5", 0.5), ("D5", 0.5), ("C5", 1)],
                [("D5", 1.5), ("B4", 0.5), ("G4", 1), (None, 1)],
                [(None, 1), ("E5", 0.5), ("E5", 0.5), ("G5", 0.5), ("E5", 0.5), ("D5", 1)],
                [("C5", 1), ("D5", 0.5), ("C5", 0.5), ("A4", 1), (None, 1)],
                [(None, 0.5), ("E5", 0.5), ("G5", 0.5), ("E5", 0.5), ("C5", 1), ("E5", 1)],
                [("D5", 2), ("B4", 1), (None, 1)],
            ],
            "pre": [
                [("D5", 2), ("F5", 2)],
                [("A5", 2), ("F5", 2)],
                [("G#5", 2), ("B5", 2)],
                [("E5", 1), ("G#5", 1), ("B5", 1), ("D6", 1)],
            ],
            "chorus": [
                [("A5", 0.5), ("A5", 0.5), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("E5", 1)],
                [("F5", 0.5), ("A5", 0.5), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("G5", 1)],
                [("G5", 0.5), ("G5", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("G5", 1)],
                [("B5", 1), ("D6", 0.5), ("B5", 0.5), ("G#5", 2)],
                [("A5", 0.5), ("A5", 0.5), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("E6", 1)],
                [("F6", 1), ("E6", 0.5), ("D6", 0.5), ("C6", 1), ("A5", 1)],
                [("G5", 0.5), ("C6", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("B5", 1)],
                [("B5", 1.5), ("G#5", 0.5), ("A5", 2)],
            ],
            "break": [
                [("E5", 2), ("A5", 2)],
                [("C6", 3), ("B5", 1)],
                [("A5", 2), ("F5", 2)],
                [("G#5", 4)],
            ],
            "hook": [
                [("A5", 0.5), ("A5", 0.5), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("E5", 1)],
                [("F5", 0.5), ("A5", 0.5), ("C6", 1), ("B5", 0.5), ("A5", 0.5), ("G5", 1)],
                [("G5", 0.5), ("G5", 0.5), ("E6", 1), ("D6", 0.5), ("C6", 0.5), ("G5", 1)],
                [("B5", 1.5), ("G#5", 0.5), ("E5", 2)],
            ],
        },
        four_on_the_floor,
    )


def make_music2():
    """Haunted Arcade: D minor at 116 bpm, on a square-wave lead and harpsichord."""
    reseed(2)
    make_song(
        "music2",
        116,
        "square",
        {
            "intro": ["Dm", "Bb", "F", "C"],
            "verse": ["Dm", "Bb", "F", "C"],
            "pre": ["Gm", "Gm", "A", "A"],
            "chorus": ["Bb", "C", "Dm", "A"],
            "break": ["Dm", "Bb", "Gm", "A"],
            "hook": ["Bb", "C", "Dm", "A"],
        },
        {
            "verse": [
                [("D5", 0.5), ("F5", 0.5), ("A5", 1), ("G5", 0.5), ("F5", 0.5), ("E5", 1)],
                [("D5", 1), ("F5", 0.5), ("D5", 0.5), ("Bb4", 2)],
                [("C5", 0.5), ("F5", 0.5), ("A5", 1), ("G5", 0.5), ("A5", 0.5), ("C6", 1)],
                [("Bb5", 1), ("A5", 0.5), ("G5", 0.5), ("E5", 2)],
                [("D5", 0.5), ("F5", 0.5), ("A5", 1), ("D6", 0.5), ("C6", 0.5), ("A5", 1)],
                [("Bb5", 1), ("A5", 0.5), ("F5", 0.5), ("D5", 2)],
                [("F5", 0.5), ("G5", 0.5), ("A5", 1), ("C6", 0.5), ("A5", 0.5), ("F5", 1)],
                [("E5", 1.5), ("G5", 0.5), ("E5", 1), ("C5", 1)],
            ],
            "pre": [
                [("G5", 1), ("Bb5", 1), ("D6", 2)],
                [("C6", 1), ("Bb5", 1), ("A5", 2)],
                [("C#6", 1), ("E6", 1), ("A5", 2)],
                [("G5", 0.5), ("A5", 0.5), ("Bb5", 0.5), ("C#6", 0.5), ("E6", 2)],
            ],
            "chorus": [
                [("D6", 0.75), ("D6", 0.75), ("C6", 0.5), ("Bb5", 1), ("F5", 1)],
                [("E6", 0.75), ("E6", 0.75), ("D6", 0.5), ("C6", 1), ("G5", 1)],
                [("F6", 0.75), ("E6", 0.75), ("D6", 0.5), ("A5", 0.5), ("D6", 0.5), ("F6", 1)],
                [("E6", 1.5), ("C#6", 0.5), ("A5", 1), (None, 1)],
                [("D6", 0.75), ("D6", 0.75), ("C6", 0.5), ("Bb5", 1), ("D6", 1)],
                [("E6", 0.75), ("E6", 0.75), ("G6", 0.5), ("E6", 1), ("C6", 1)],
                [("F6", 0.75), ("E6", 0.75), ("D6", 0.5), ("C6", 0.5), ("A5", 0.5), ("F5", 1)],
                [("E5", 0.5), ("A5", 0.5), ("C#6", 0.5), ("E6", 0.5), ("D6", 2)],
            ],
            "break": [
                [("A5", 4)],
                [("F5", 2), ("D5", 2)],
                [("G5", 2), ("Bb5", 2)],
                [("C#6", 2), ("E6", 2)],
            ],
            "hook": [
                [("D6", 0.75), ("D6", 0.75), ("C6", 0.5), ("Bb5", 1), ("F5", 1)],
                [("E6", 0.75), ("E6", 0.75), ("D6", 0.5), ("C6", 1), ("G5", 1)],
                [("F6", 0.75), ("E6", 0.75), ("D6", 0.5), ("A5", 0.5), ("D6", 0.5), ("F6", 1)],
                [("E6", 1.5), ("C#6", 0.5), ("A5", 2)],
            ],
        },
        bounce,
    )


def make_ambience():
    """Wind through dead trees, a distant drone, creaks and a far-off bell."""
    reseed(3)
    length = 48
    track = np.zeros(int((length + 4) * RATE))

    # The wind is filtered over exactly one loop, and its gusts repeat within
    # it, so it runs on round the loop without a seam.
    t = times(length)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12) * np.sin(2 * np.pi * t / 8 + 1)
    wind = band(noise(length), 250, 900) * (0.3 + 0.7 * gust)
    howl = band(noise(length), 500, 700) * (gust**3) * 2
    track[: len(t)] += wind * 0.6 + howl * 0.5
    track += organ(note("D2"), len(track) / RATE, 0.05, attack=4, release=4)
    track += organ(note("Ab2"), len(track) / RATE, 0.03, attack=6, release=6)

    for at in (5, 19, 33, 41):
        # A creak: a short, rough glide.
        seconds = rng.uniform(0.6, 1.2)
        ct = times(seconds)
        freq = rng.uniform(180, 260) * (1 + 0.4 * ct / seconds)
        phase = 2 * np.pi * np.cumsum(freq) / RATE
        creak = np.sign(np.sin(phase)) * np.sin(phase * 0.5) * np.exp(-((ct - seconds / 2) ** 2) / (seconds / 4) ** 2)
        place(track, band(creak, 150, 2500) * 0.12, at)
    for at in (12, 36):
        place(track, bell(note("A2"), 6, 0.12), at)

    left = loop(reverb(track, seconds=3, wet=0.5, seed=3), length)
    right = loop(reverb(track, seconds=3, wet=0.5, seed=4), length)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    write("ambience", [left * 0.75 / peak, right * 0.75 / peak])


def make_claim():
    """A gong and a rising, eerie chord when a plot is claimed."""
    reseed(4)
    track = np.zeros(int(3.5 * RATE))
    place(track, bell(note("D2"), 3.5, 0.6), 0)
    place(track, thud(1, 0.6, 70, 30), 0)
    for i, name in enumerate(["D4", "F4", "A4", "D5"]):
        place(track, organ(note(name), 2.6 - i * 0.15, 0.12, attack=0.4, release=1), 0.15 + i * 0.15)
    for i, name in enumerate(["A5", "D6", "F6", "A6"]):
        place(track, music_box(note(name), 2, 0.3), 0.4 + i * 0.12)
    write("claim", [normalise(reverb(track, wet=0.35)[: int(3.5 * RATE)])])


def make_purchase():
    """A cash-register style ching: two bright metallic hits and a shimmer."""
    reseed(5)
    track = np.zeros(int(1.2 * RATE))
    for at, freq in ((0, 1568), (0.09, 2093)):
        place(track, music_box(freq, 1, 0.7), at)
        place(track, music_box(freq * 1.5, 0.8, 0.3), at)
    shimmer = band(noise(0.5), 5000, 12000) * np.exp(-times(0.5) * 9) * 0.25
    place(track, shimmer, 0.09)
    write("purchase", [normalise(reverb(track, seconds=1.2, wet=0.2)[: int(1.2 * RATE)])])


def make_build():
    """A whoosh up from the ground, a thud, and a little chime."""
    reseed(6)
    track = np.zeros(int(1.6 * RATE))
    whoosh = sweep(noise(0.6), 200, 3000) * np.sin(np.pi * times(0.6) / 0.6) ** 2
    place(track, whoosh * 0.8, 0)
    place(track, thud(0.6, 0.9, 120, 45), 0.55)
    for i, name in enumerate(["D6", "A6"]):
        place(track, music_box(note(name), 1, 0.35), 0.6 + i * 0.08)
    write("build", [normalise(reverb(track, seconds=1.5, wet=0.25)[: int(1.6 * RATE)])])


def make_payout():
    """A run of coins dropping into a pile."""
    reseed(7)
    track = np.zeros(int(1.2 * RATE))
    for i in range(6):
        freq = 2600 - i * 180 + rng.uniform(-60, 60)
        place(track, music_box(freq, 0.5, 0.5 - i * 0.05), i * 0.06 + rng.uniform(0, 0.015))
    write("payout", [normalise(reverb(track, seconds=1, wet=0.2)[: int(1.2 * RATE)])])


if __name__ == "__main__":
    make_music()
    make_music2()
    make_ambience()
    make_claim()
    make_purchase()
    make_build()
    make_payout()
