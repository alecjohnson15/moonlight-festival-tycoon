"""Makes the festival's place and event sounds, synthesised from sine waves
and noise with the helpers in make_sounds.py, so the project owns them
outright: a reveal sting for each building, the ambience of each place
(the festival crowd, the graveyard choir, the arena drums), the Moonlight
Parade's fanfare, catch, cheer and march, the Terror Train's wail and the
trail reaper's whisper. Run it with Python 3 and numpy, with ffmpeg on the
path:

    python3 tools/make_festival_sounds.py            # all of them
    python3 tools/make_festival_sounds.py parade_march train_wail

It writes assets/audio/<name>.ogg. Upload those to Roblox and paste their
asset ids into Sounds in src/shared/Themes/MoonlightFestival/init.luau,
under the matching name (parade_march.ogg is ParadeMarch, and so on).
"""

import sys

import numpy as np

import make_sounds
from make_sounds import (
    RATE,
    Song,
    band,
    bell,
    clap,
    crash,
    hz,
    loop,
    music_box,
    noise,
    normalise,
    note,
    organ,
    place,
    pluck,
    reseed,
    reverb,
    saw_bass,
    snare,
    sweep,
    thud,
    times,
    voicing,
    write,
)

# Vowel formants (first and second), for voices made from a buzz or breath.
VOWELS = {"a": (730, 1090), "e": (530, 1840), "o": (570, 840), "oo": (300, 870), "i": (390, 2000)}


def saw(freq):
    """A plain sawtooth following a frequency curve, for voices to shape."""
    phase = np.cumsum(freq) / RATE
    return 2 * (phase % 1) - 1


def vowel(signal, name):
    """Shapes a buzz or breath into a vowel with its two formants."""
    first, second = VOWELS[name]
    return band(signal, first * 0.8, first * 1.25) + 0.6 * band(signal, second * 0.85, second * 1.2)


def brass(freq, seconds, amp=1.0):
    """A bright horn: a buzzy tone that opens up as it starts."""
    t = times(seconds + 0.1)
    wobble = 1 + 0.004 * np.sin(2 * np.pi * 5 * t) * np.minimum(1, t / 0.4)
    phase = 2 * np.pi * freq * np.cumsum(wobble) / RATE
    bright = 0.3 + 0.7 * np.minimum(1, t / 0.06)
    out = sum(np.sin(n * phase) / n * bright ** (n / 3) for n in range(1, 14) if freq * n < 9000)
    shape = np.minimum(1, t / 0.02) * np.clip((seconds + 0.1 - t) / 0.1, 0, 1)
    return amp * out * shape


def babble(seconds, voices, seed, low=110, high=240):
    """A crowd talking: buzzing voices shaped into changing vowels, in
    bursts of syllables with pauses between."""
    local = np.random.default_rng(seed)
    t = times(seconds)
    total = np.zeros(len(t))
    names = list(VOWELS)
    for _ in range(voices):
        drift = 1 + 0.06 * np.sin(2 * np.pi * local.uniform(0.1, 0.4) * t + local.uniform(0, 6))
        source = saw(local.uniform(low, high) * drift)
        shapes = [vowel(source, names[i]) for i in local.choice(len(names), 2, replace=False)]
        levels = [np.zeros(len(t)) for _ in shapes]
        at = local.uniform(0, 1.5)
        while at < seconds:
            for _ in range(local.integers(3, 9)):
                length = local.uniform(0.08, 0.22)
                start, count = int(at * RATE), int(length * RATE)
                end = min(len(t), start + count)
                if start < end:
                    levels[local.integers(0, len(levels))][start:end] += (
                        np.hanning(count)[: end - start] * local.uniform(0.5, 1)
                    )
                at += length + local.uniform(0.02, 0.1)
            at += local.uniform(0.5, 2.5)
        total += sum(shape * level for shape, level in zip(shapes, levels)) * local.uniform(0.5, 1)
    return total


def stereo_loop(track, length, wet, seeds, peak=0.75, room=3):
    """Two slightly different rooms, one per ear, folded into a seamless
    loop."""
    left = loop(reverb(track, seconds=room, wet=wet, seed=seeds[0]), length)
    right = loop(reverb(track, seconds=room, wet=wet, seed=seeds[1]), length)
    top = max(np.max(np.abs(left)), np.max(np.abs(right)))
    return [left * peak / top, right * peak / top]


def sting(name, track, seconds, wet=0.3, seed=0, peak=0.8):
    write(name, [normalise(reverb(track, seconds=1.4, wet=wet, seed=seed)[: int(seconds * RATE)], peak)])


# Reveal stings: one for each building, played as it or anything for it is
# built (Theme.Reveals).


def make_reveal_stall():
    """The candy stall: a sparkly music-box run up and a sweet chord."""
    reseed(101)
    track = np.zeros(int(1.8 * RATE))
    for i, name in enumerate(["C6", "E6", "G6", "C7"]):
        place(track, music_box(note(name), 1.0, 0.45), i * 0.07)
    for name in ("C5", "E5", "G5"):
        place(track, pluck(note(name), 1.2, 0.35, bright=True), 0.3)
    place(track, band(noise(0.6), 6000, 13000) * np.exp(-times(0.6) * 7) * 0.2, 0.25)
    sting("reveal_stall", track, 1.8, seed=101)


def make_reveal_patch():
    """The pumpkin patch: a woody knock, plucks climbing out of the earth
    and a rustle of leaves."""
    reseed(102)
    track = np.zeros(int(1.9 * RATE))
    place(track, thud(0.6, 0.9, 110, 45), 0)
    for i, name in enumerate(["D4", "F4", "A4", "D5"]):
        place(track, pluck(note(name), 0.8, 0.5), 0.12 + i * 0.1)
    rustle = band(noise(0.7), 1500, 6000) * np.random.default_rng(102).uniform(0, 1, int(0.7 * RATE)) ** 4
    place(track, rustle * np.sin(np.pi * times(0.7) / 0.7) * 0.6, 0.05)
    place(track, organ(note("D3"), 1.2, 0.12, attack=0.2, release=0.8), 0.45)
    sting("reveal_patch", track, 1.9, seed=102)


def make_reveal_kitchen():
    """The witch's kitchen: a cauldron's bubbles, a bong and a shimmer of
    magic."""
    reseed(103)
    local = np.random.default_rng(103)
    track = np.zeros(int(2.0 * RATE))
    for _ in range(14):
        seconds = local.uniform(0.03, 0.07)
        t = times(seconds)
        freq = local.uniform(250, 500) * (1 + 2.5 * t / seconds)
        blip = np.sin(2 * np.pi * np.cumsum(freq) / RATE) * np.sin(np.pi * t / seconds)
        place(track, blip * local.uniform(0.2, 0.4), local.uniform(0, 0.7))
    place(track, bell(note("D3"), 1.6, 0.45), 0.6)
    place(track, sweep(noise(0.9), 1500, 9000) * np.sin(np.pi * times(0.9) / 0.9) ** 2 * 0.3, 0.6)
    for i, name in enumerate(["A5", "D6", "F6"]):
        place(track, music_box(note(name), 0.9, 0.25), 0.75 + i * 0.09)
    sting("reveal_kitchen", track, 2.0, seed=103)


def make_reveal_maze():
    """The scream maze, kept mild: a ghost's swooping "ooo", a rush of air
    and a soft thud."""
    reseed(104)
    track = np.zeros(int(2.1 * RATE))
    t = times(1.5)
    freq = note("A4") * (1 + 0.5 * np.sin(np.pi * t / 1.5) ** 2) * (1 + 0.01 * np.sin(2 * np.pi * 6 * t))
    phase = 2 * np.pi * np.cumsum(freq) / RATE
    ghost = (np.sin(phase) + 0.2 * np.sin(2 * phase)) * np.sin(np.pi * t / 1.5) ** 1.5
    place(track, ghost * 0.4, 0)
    place(track, sweep(noise(0.7), 3000, 300) * np.sin(np.pi * times(0.7) / 0.7) ** 2 * 0.6, 0.9)
    place(track, thud(0.7, 0.8, 90, 38), 1.4)
    sting("reveal_maze", track, 2.1, wet=0.4, seed=104)


def make_reveal_pumpkin():
    """The great pumpkin: a deep bell and a harpsichord flourish."""
    reseed(105)
    track = np.zeros(int(2.3 * RATE))
    place(track, bell(note("D2"), 2.3, 0.5), 0)
    for i, name in enumerate(["D5", "F5", "A5", "D6", "F6"]):
        place(track, pluck(note(name), 0.9, 0.45, bright=True), 0.1 + i * 0.07)
    for name in ("D4", "A4", "D5"):
        place(track, organ(note(name), 1.6, 0.1, attack=0.15, release=1), 0.45)
    sting("reveal_pumpkin", track, 2.3, seed=105)


def make_reveal_train():
    """The Terror Train: chuffs speeding up, a two-tone whistle and a bell."""
    reseed(106)
    track = np.zeros(int(2.4 * RATE))
    at = 0.0
    for i in range(7):
        chuff = band(noise(0.15), 250, 2500) * np.exp(-times(0.15) * 22)
        place(track, chuff * (0.5 if i % 2 else 0.8), at)
        at += 0.22 - i * 0.02
    t = times(1.1)
    whistle = sum(np.sin(2 * np.pi * note(name) * (1 + 0.02 * np.minimum(1, t / 0.2)) * t) for name in ("Bb4", "Db5"))
    whistle = whistle + band(noise(1.1), 1500, 4000) * 0.15
    place(track, whistle * np.minimum(1, t / 0.05) * np.clip((1.1 - t) / 0.3, 0, 1) * 0.35, 1.0)
    place(track, bell(note("F5"), 1.2, 0.25), 1.05)
    sting("reveal_train", track, 2.4, seed=106)


# Ambience by place (Scenery's sound zones). Each loops without a seam.


def make_ambience_crowd():
    """The festival: a crowd chattering, a far-off fairground organ playing
    a slow waltz, and now and then a cheer."""
    reseed(107)
    length = 40
    track = np.zeros(int((length + 4) * RATE))
    track += babble(length + 4, 16, 107) * 0.12
    # The waltz, written for this project: three beats a bar, in A minor.
    beat = 0.5
    tune = [
        ("A4", 1), ("C5", 1), ("E5", 1), ("D5", 2), ("C5", 1), ("B4", 1), ("G#4", 1), ("B4", 1),
        ("E4", 3), ("A4", 1), ("C5", 1), ("E5", 1), ("A5", 2), ("G5", 1), ("F5", 1), ("E5", 1),
        ("D5", 1), ("E5", 3), ("F5", 1), ("E5", 1), ("D5", 1), ("C5", 2), ("B4", 1), ("A4", 1),
        ("B4", 1), ("C5", 1), ("E5", 3), ("D5", 1), ("C5", 1), ("B4", 1), ("A4", 3),
    ]
    chords = ["Am", "E", "Am", "E", "Am", "F", "Dm", "E", "F", "Am", "Dm", "E", "Am", "E", "Am", "Am"]
    for repeat in range(2):
        start = 2 + repeat * 20
        at = start
        for name, beats in tune:
            place(track, organ(note(name), beats * beat, 0.05, attack=0.02, release=0.08), at)
            place(track, music_box(note(name) * 2, 0.6, 0.03), at)
            at += beats * beat
        for bar, chord in enumerate(chords):
            root = voicing(chord, 45)[0]
            place(track, organ(hz(root), beat * 0.9, 0.04, attack=0.01, release=0.1), start + bar * 3 * beat)
            for step in (1, 2):
                for tone in voicing(chord, 57):
                    place(
                        track,
                        organ(hz(tone), beat * 0.5, 0.015, attack=0.01, release=0.05),
                        start + (bar * 3 + step) * beat,
                    )
    for at in (9, 27):
        t = times(2.5)
        cheer = band(noise(2.5), 500, 3500) * np.sin(np.pi * t / 2.5) ** 2
        place(track, cheer * 0.08, at)
    write("ambience_crowd", stereo_loop(track, length, 0.45, (107, 108), peak=0.7))


def make_ambience_choir():
    """The graveyard: a low choir singing "ooh" through four slow minor
    chords, wind through the stones and a distant bell."""
    reseed(109)
    local = np.random.default_rng(109)
    length = 48
    track = np.zeros(int((length + 4) * RATE))
    for index, chord in enumerate(["Dm", "Bb", "Gm", "A"]):
        start = index * 12
        tones = voicing(chord, 50) + [voicing(chord, 38)[0]]
        for tone in tones:
            for _ in range(3):
                seconds = 14
                t = times(seconds)
                freq = hz(tone) * 2 ** (local.uniform(-6, 6) / 1200)
                freq = freq * (1 + 0.004 * np.sin(2 * np.pi * local.uniform(4.5, 5.5) * t + local.uniform(0, 6)))
                voice = vowel(saw(freq), "oo" if tone > 46 else "o")
                shape = np.minimum(1, t / 3) * np.clip((seconds - t) / 3, 0, 1)
                place(track, voice * shape * 0.05, start - 1)
    t = times(length + 4)
    gust = 0.5 + 0.5 * np.sin(2 * np.pi * t / 12) * np.sin(2 * np.pi * t / 16 + 2)
    track += band(noise(length + 4), 200, 800) * (0.2 + 0.5 * gust) * 0.3
    for at in (8, 32):
        place(track, bell(note("D2"), 6, 0.15), at)
    write("ambience_choir", stereo_loop(track, length, 0.55, (109, 110), peak=0.7, room=4))


def make_ambience_drums():
    """The arena: big frame drums and toms with a shaker, the torches
    crackling and the crowd murmuring."""
    reseed(111)
    local = np.random.default_rng(111)
    bpm = 90
    beat = 60 / bpm
    bars = 12
    length = bars * 4 * beat
    track = np.zeros(int((length + 4) * RATE))
    toms = [[1, 1.5, 3, 3.25, 3.5], [1.5, 3, 3.5], [0.75, 1, 3, 3.25], [1, 1.5, 2.75, 3, 3.25, 3.5, 3.75]]
    for bar in range(bars):
        start = bar * 4 * beat
        place(track, thud(0.9, 1.0, 80, 42), start)
        place(track, thud(0.9, 0.8, 80, 42), start + 2.5 * beat)
        for hit in toms[bar % 4]:
            place(track, thud(0.4, 0.45, 170, 95), start + hit * beat)
        for step in range(8):
            shake = band(noise(0.12), 5000, 11000) * np.exp(-times(0.12) * 30)
            place(track, shake * (0.14 if step % 2 else 0.08), start + step * beat / 2)
    for _ in range(int(length * 6)):
        click = band(noise(0.02), 1500, 7000) * np.exp(-times(0.02) * 200)
        place(track, click * local.uniform(0.02, 0.08), local.uniform(0, length))
    track += babble(length + 4, 10, 112) * 0.05
    track += organ(note("D2"), length + 4, 0.04, attack=4, release=4)
    write("ambience_drums", stereo_loop(track, length, 0.3, (111, 112), peak=0.75, room=2))


# The Moonlight Parade.


def make_parade_start():
    """The parade setting off: a snare roll, a horn fanfare and a crash."""
    reseed(113)
    track = np.zeros(int(2.8 * RATE))
    for i in range(12):
        place(track, snare(0.25 + i * 0.03), i * 0.04)
    phrase = [("A4", 0.13), ("A4", 0.13), ("A4", 0.13), ("D5", 0.4), ("F#5", 0.3), ("A5", 1.1)]
    at = 0.5
    for name, seconds in phrase:
        place(track, brass(note(name), seconds * 0.9, 0.3), at)
        place(track, brass(note(name) / 2, seconds * 0.9, 0.15), at)
        at += seconds
    place(track, crash(0.3), 0.5 + 1.09)
    place(track, bell(note("D5"), 1.2, 0.2), 0.5 + 1.09)
    sting("parade_start", track, 2.8, wet=0.3, seed=113)


def make_parade_catch():
    """A lantern caught: two twinkles up a fourth, higher than Ghost
    Catcher's."""
    reseed(114)
    track = np.zeros(int(0.7 * RATE))
    place(track, music_box(note("G6"), 0.4, 0.55), 0)
    place(track, music_box(note("C7"), 0.5, 0.45), 0.05)
    place(track, band(noise(0.25), 7000, 13000) * np.exp(-times(0.25) * 16) * 0.18, 0.04)
    sting("parade_catch", track, 0.7, wet=0.2, seed=114, peak=0.7)


def make_parade_cheer():
    """The meter full: the crowd cheering "yay", clapping, and bells."""
    reseed(115)
    local = np.random.default_rng(115)
    seconds = 3.0
    track = np.zeros(int(seconds * RATE))
    for _ in range(18):
        length = local.uniform(1.0, 1.8)
        t = times(length)
        rise = local.uniform(180, 320) * (1 + 0.25 * np.minimum(1, t / 0.4)) * (1 - 0.15 * t / length)
        source = saw(rise)
        shout = vowel(source, "e") * np.clip(1 - t / 0.3, 0, 1) + vowel(source, "a") * np.minimum(1, t / 0.3)
        shape = np.minimum(1, t / 0.08) * np.exp(-t * 1.6)
        place(track, shout * shape * local.uniform(0.04, 0.08), local.uniform(0, 0.35))
    for _ in range(40):
        place(track, clap(local.uniform(0.05, 0.12)), local.uniform(0.2, 2.4))
    for i, name in enumerate(["D6", "F#6", "A6", "D7"]):
        place(track, music_box(note(name), 1.2, 0.3), 0.1 + i * 0.08)
    sting("parade_cheer", track, seconds, wet=0.35, seed=115)


def make_parade_march():
    """The parade's march: sixteen bars of a spooky, bouncy oom-pah in D
    minor with a glockenspiel tune, written for this project."""
    reseed(116)
    song = Song(112, 16)
    chords = ["Dm", "Dm", "A", "A", "Dm", "Dm", "Gm", "A", "Bb", "F", "Gm", "A", "Dm", "Gm", "A", "Dm"]
    tune = [
        [("D5", 1), ("F5", 1), ("A5", 1), ("F5", 1)],
        [("D5", 1), ("A4", 1), ("D5", 2)],
        [("E5", 1), ("G5", 1), ("A5", 1), ("G5", 1)],
        [("E5", 1), ("C#5", 1), ("A4", 2)],
        [("D5", 0.5), ("E5", 0.5), ("F5", 1), ("A5", 1), ("D6", 1)],
        [("C6", 1), ("A5", 1), ("F5", 2)],
        [("G5", 1), ("Bb5", 1), ("A5", 1), ("G5", 1)],
        [("E5", 2), ("A4", 2)],
        [("F5", 1), ("D5", 1), ("Bb4", 1), ("D5", 1)],
        [("F5", 1), ("A5", 1), ("C6", 2)],
        [("Bb5", 1), ("G5", 1), ("D5", 1), ("G5", 1)],
        [("A5", 1), ("E5", 1), ("C#5", 2)],
        [("D5", 1), ("F5", 1), ("A5", 1), ("D6", 1)],
        [("Bb5", 1), ("G5", 1), ("D5", 2)],
        [("E5", 0.5), ("F5", 0.5), ("G5", 1), ("A5", 1), ("C#6", 1)],
        [("D6", 2), ("A5", 1), (None, 1)],
    ]
    for bar, chord in enumerate(chords):
        root, fifth = voicing(chord, 38)[0], voicing(chord, 38)[0] + 7
        # Oom (the tuba) on one and three, pah (the chord) on two and four.
        song.add("bass", saw_bass(hz(root), song.beat * 0.8, 0.5, cutoff=400), song.at(bar, 0))
        song.add("bass", saw_bass(hz(fifth), song.beat * 0.8, 0.45, cutoff=400), song.at(bar, 2))
        for step in (1, 3):
            for i, tone in enumerate(voicing(chord, 55)):
                song.add("keys", pluck(hz(tone), song.beat * 0.6, 0.12), song.at(bar, step), pan=-0.3 + i * 0.3)
        song.kick(song.at(bar, 0), 0.6)
        song.kick(song.at(bar, 2), 0.5)
        for step in (1, 3):
            song.add("drums", snare(0.35), song.at(bar, step), pan=0.2)
        if bar % 4 == 3:
            for i in range(4):
                song.add("drums", snare(0.15 + i * 0.05), song.at(bar, 3.5 + i * 0.125), pan=0.2)
        at = 0.0
        for name, beats in tune[bar]:
            if name:
                song.add("bells", music_box(note(name), 1.2, 0.35), song.at(bar, at), pan=0.25)
                song.add("lead", pluck(note(name) / 2, beats * song.beat, 0.18, bright=True), song.at(bar, at), pan=-0.2)
            at += beats
    song.mix("parade_march")


def make_train_wail():
    """The Terror Train in its tunnel, heard up close: steady chuffing and,
    once a loop, a ghostly two-note whistle that sags as it fades."""
    reseed(117)
    length = 10
    track = np.zeros(int((length + 3) * RATE))
    at = 0.0
    step = 0
    while at < length:
        chuff = band(noise(0.16), 220, 2200) * np.exp(-times(0.16) * 20)
        place(track, chuff * (0.45 if step % 2 else 0.7), at)
        at += 0.26
        step += 1
    t = times(2.4)
    bend = (1 + 0.04 * np.minimum(1, t / 0.3)) * (1 - 0.12 * np.clip((t - 1.2) / 1.2, 0, 1))
    whistle = sum(np.sin(2 * np.pi * np.cumsum(note(name) * bend) / RATE) for name in ("A4", "C5"))
    whistle = whistle + band(noise(2.4), 1200, 3500) * 0.2
    shape = np.minimum(1, t / 0.15) * np.clip((2.4 - t) / 0.8, 0, 1)
    place(track, whistle * shape * 0.3, 1.5)
    write("train_wail", stereo_loop(track, length, 0.4, (117, 118), peak=0.75, room=2))


def make_reaper_whisper():
    """The trail reaper turning to watch: a breathy whisper with no words,
    over a low swell. Spooky, not frightening."""
    reseed(119)
    seconds = 2.6
    track = np.zeros(int(seconds * RATE))
    for at, length, sound in ((0.1, 0.5, "hh"), (0.55, 0.6, "a"), (1.2, 0.5, "hh"), (1.6, 0.7, "oo")):
        breath = noise(length)
        if sound == "hh":
            shaped = band(breath, 1500, 5000)
        else:
            shaped = vowel(breath, sound) * 1.5
        place(track, shaped * np.hanning(int(length * RATE)) * 0.25, at)
    place(track, organ(note("D2"), 2.4, 0.12, attack=0.8, release=1.2), 0)
    write("reaper_whisper", [normalise(reverb(track, seconds=2, wet=0.5, seed=119)[: len(track)], 0.7)])


MAKERS = {
    "reveal_stall": make_reveal_stall,
    "reveal_patch": make_reveal_patch,
    "reveal_kitchen": make_reveal_kitchen,
    "reveal_maze": make_reveal_maze,
    "reveal_pumpkin": make_reveal_pumpkin,
    "reveal_train": make_reveal_train,
    "ambience_crowd": make_ambience_crowd,
    "ambience_choir": make_ambience_choir,
    "ambience_drums": make_ambience_drums,
    "parade_start": make_parade_start,
    "parade_catch": make_parade_catch,
    "parade_cheer": make_parade_cheer,
    "parade_march": make_parade_march,
    "train_wail": make_train_wail,
    "reaper_whisper": make_reaper_whisper,
}


if __name__ == "__main__":
    wanted = sys.argv[1:] or list(MAKERS)
    unknown = [name for name in wanted if name not in MAKERS]
    if unknown:
        sys.exit(f"unknown sounds: {', '.join(unknown)} (known: {', '.join(MAKERS)})")
    for name in wanted:
        MAKERS[name]()
    assert make_sounds.RATE == RATE
