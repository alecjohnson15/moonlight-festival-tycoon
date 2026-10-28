"""Makes the PvP arena's original sounds, synthesised from sine waves and
noise with the helpers in make_sounds.py, so the project owns them outright.
Run it with Python 3 and numpy, with ffmpeg on the path:

    python3 tools/make_arena_sounds.py

It writes assets/audio/arena_*.ogg. Upload those to Roblox and paste their
asset ids into Sounds in src/shared/Themes/MoonlightFestival/Arena.luau.
"""

import numpy as np

from make_sounds import RATE, band, music_box, noise, normalise, note, place, reverb, sweep, thud, times, write


def make_bonk():
    """A cartoon bonk: a hollow wooden knock with a springy wobble."""
    track = np.zeros(int(0.7 * RATE))
    t = times(0.5)
    wobble = 1 + 0.06 * np.sin(2 * np.pi * 18 * t) * np.exp(-t * 6)
    knock = sum(
        level * np.sin(2 * np.pi * freq * np.cumsum(wobble) / RATE) * np.exp(-t * decay)
        for freq, level, decay in ((410, 1.0, 14), (1030, 0.45, 26), (1720, 0.2, 40))
    )
    place(track, knock * np.minimum(1, t / 0.002), 0)
    place(track, thud(0.4, 0.8, 180, 70), 0)
    place(track, band(noise(0.03), 2000, 7000) * np.exp(-times(0.03) * 120) * 0.6, 0)
    write("arena_bonk", [normalise(reverb(track, seconds=0.6, wet=0.12)[: len(track)])])


def make_knockout():
    """Knocked out: a slide whistle falling away, a soft flop and dizzy twinkles."""
    track = np.zeros(int(1.8 * RATE))
    t = times(0.8)
    freq = 1500 * (300 / 1500) ** (t / 0.8) * (1 + 0.03 * np.sin(2 * np.pi * 7 * t))
    whistle = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.minimum(1, t / 0.02) * np.minimum(1, (0.8 - t) / 0.1)
    place(track, whistle * 0.6, 0)
    place(track, thud(0.5, 0.9, 110, 45), 0.75)
    for i, name in enumerate(["E7", "B6", "G#6", "E7", "B6"]):
        place(track, music_box(note(name), 0.5, 0.25), 0.85 + i * 0.12)
    write("arena_knockout", [normalise(reverb(track, seconds=1.2, wet=0.2)[: len(track)])])


def make_special():
    """A special move winding up: a rising whoosh with a shimmer on top."""
    track = np.zeros(int(1.0 * RATE))
    whoosh = sweep(noise(0.6), 250, 3500) * np.sin(np.pi * times(0.6) / 0.6) ** 2
    place(track, whoosh, 0)
    for i, name in enumerate(["D6", "A6", "D7"]):
        place(track, music_box(note(name), 0.6, 0.2), 0.2 + i * 0.07)
    write("arena_special", [normalise(reverb(track, seconds=1, wet=0.25)[: len(track)])])


def make_thunder():
    """A crack of thunder and a long, low rumble."""
    track = np.zeros(int(3.0 * RATE))
    crack = band(noise(0.25), 400, 9000) * np.exp(-times(0.25) * 22)
    place(track, crack, 0)
    t = times(2.8)
    rumble = band(noise(2.8), 25, 220) * np.exp(-t * 1.4) * (1 + 0.5 * np.sin(2 * np.pi * 3 * t))
    place(track, rumble * 2.5, 0.05)
    place(track, thud(0.8, 1.0, 70, 30), 0.02)
    write("arena_thunder", [normalise(reverb(track, seconds=2, wet=0.3)[: len(track)])])


if __name__ == "__main__":
    make_bonk()
    make_knockout()
    make_special()
    make_thunder()
