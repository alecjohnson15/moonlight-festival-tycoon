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


def make_music():
    """A slow, crooked music-box waltz in D minor over an organ drone."""
    beat = 60 / 76
    bar = beat * 3
    bars = 16
    length = bars * bar
    track = np.zeros(int((length + 4) * RATE))

    chords = ["Dm", "Dm", "Bb", "Bb", "Gm", "Gm", "A", "A", "Dm", "Dm", "Bb", "Gm", "Gm", "A", "Dm", "A"]
    roots = {"Dm": ("D2", "A2", "F3"), "Bb": ("Bb1", "F2", "D3"), "Gm": ("G1", "D2", "Bb2"), "A": ("A1", "E2", "C#3")}
    melody = [
        [("A5", 1), ("D6", 1), ("F6", 1)],
        [("E6", 1.5), ("D6", 0.5), ("A5", 1)],
        [("Bb5", 1), ("D6", 1), ("F6", 1)],
        [("F6", 1.5), ("E6", 0.5), ("D6", 1)],
        [("G5", 1), ("Bb5", 1), ("D6", 1)],
        [("C#6", 1.5), ("D6", 0.5), ("Bb5", 1)],
        [("A5", 1), ("C#6", 1), ("E6", 1)],
        [("A6", 2), ("G#5", 1)],
        [("A5", 1), ("D6", 1), ("F6", 1)],
        [("A6", 1.5), ("G6", 0.5), ("F6", 1)],
        [("F6", 1), ("D6", 1), ("Bb5", 1)],
        [("G5", 1), ("Bb5", 0.5), ("D6", 0.5), ("G6", 1)],
        [("F6", 1), ("E6", 0.5), ("D6", 0.5), ("Bb5", 1)],
        [("C#6", 1.5), ("E6", 0.5), ("A5", 1)],
        [("D6", 1), ("F5", 1), ("A5", 1)],
        [("E5", 1), ("C#5", 1), ("A4", 1)],
    ]

    for index, (chord, notes) in enumerate(zip(chords, melody)):
        start = index * bar
        # The tune, slightly out of time so it sounds like a worn-out box.
        at = start
        for name, beats in notes:
            wobble = rng.uniform(-0.012, 0.012)
            place(track, music_box(note(name), 2.5, 0.5), at + wobble)
            at += beats * beat
        # The drone under it.
        for name in roots[chord]:
            place(track, organ(note(name), bar + 0.6, 0.09, attack=0.5, release=0.5), start)
        # A low heartbeat on the first beat of every other bar.
        if index % 2 == 0:
            place(track, thud(amp=0.5), start)
            place(track, thud(amp=0.3), start + 0.28)

    # A bell tolls at the start of each half.
    for at in (0, 8 * bar):
        place(track, bell(note("D3"), 4, 0.25), at)

    left = loop(reverb(track, wet=0.4, seed=1), length)
    right = loop(reverb(track, wet=0.4, seed=2), length)
    peak = max(np.max(np.abs(left)), np.max(np.abs(right)))
    write("music", [left * 0.75 / peak, right * 0.75 / peak])


def make_ambience():
    """Wind through dead trees, a distant drone, creaks and a far-off bell."""
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
    track = np.zeros(int(1.2 * RATE))
    for at, freq in ((0, 1568), (0.09, 2093)):
        place(track, music_box(freq, 1, 0.7), at)
        place(track, music_box(freq * 1.5, 0.8, 0.3), at)
    shimmer = band(noise(0.5), 5000, 12000) * np.exp(-times(0.5) * 9) * 0.25
    place(track, shimmer, 0.09)
    write("purchase", [normalise(reverb(track, seconds=1.2, wet=0.2)[: int(1.2 * RATE)])])


def make_build():
    """A whoosh up from the ground, a thud, and a little chime."""
    track = np.zeros(int(1.6 * RATE))
    whoosh = sweep(noise(0.6), 200, 3000) * np.sin(np.pi * times(0.6) / 0.6) ** 2
    place(track, whoosh * 0.8, 0)
    place(track, thud(0.6, 0.9, 120, 45), 0.55)
    for i, name in enumerate(["D6", "A6"]):
        place(track, music_box(note(name), 1, 0.35), 0.6 + i * 0.08)
    write("build", [normalise(reverb(track, seconds=1.5, wet=0.25)[: int(1.6 * RATE)])])


def make_payout():
    """A run of coins dropping into a pile."""
    track = np.zeros(int(1.2 * RATE))
    for i in range(6):
        freq = 2600 - i * 180 + rng.uniform(-60, 60)
        place(track, music_box(freq, 0.5, 0.5 - i * 0.05), i * 0.06 + rng.uniform(0, 0.015))
    write("payout", [normalise(reverb(track, seconds=1, wet=0.2)[: int(1.2 * RATE)])])


if __name__ == "__main__":
    make_music()
    make_ambience()
    make_claim()
    make_purchase()
    make_build()
    make_payout()
