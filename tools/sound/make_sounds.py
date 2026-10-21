"""Render all of Anomaly Hunter's sounds.

    python tools/sound/make_sounds.py [out_dir]

Writes, into out_dir (default: tools/sound/out):
  EventStingers.ogg   every event's warning and start sound, one after another
  EventAmbience.ogg   every event's background loop, one after another
  MusicWaltz.ogg         The Haunted Waltz (our own tune)
  MusicMountainKing.ogg  after Grieg, In the Hall of the Mountain King (1875)
  MusicLullaby.ogg       Lullaby for the Lost (our own tune)
  MusicMoonlight.ogg     after Beethoven, Moonlight Sonata, first movement (1801)
  preview/*.mp3       each sound on its own, for the preview page
  WorldAmbience.ogg   the night under the music, and the little sounds between songs
  regions.json        where each sound sits inside the two event files

It also rewrites src/shared/Config/SoundSheets.luau with those positions, so the game plays
the right slices after a re-render (upload the new files and keep the ids in Config/Sounds).

The two event files are "sound sheets": one upload holds many sounds, and the game plays
just the right slice (Sound.PlaybackRegion / Sound.LoopRegion). That keeps the number of
uploads small. Every sound is synthesized here from scratch, and the three compositions
are long in the public domain, so all of it is ours to use.
"""

import json
import os
import subprocess
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(__file__))
from synth import *  # noqa: E402,F403

# Each sound gets its own random seed, so changing one sound never changes another. Sounds
# Giles reviewed keep the exact random state they were first made with, so a re-render gives
# the very same sound (new sounds are seeded from their name).
APPROVED = {  # name: (PCG64 state, has_uint32, uinteger)
    "FrostFogWarning": (78419187311282569393360609524915227602, 0, 0),
    "FrostFogStart": (7008574173270448166590076889761042112, 0, 0),
    "SugarRushWarning": (102585170012589833832176388980571577185, 0, 0),
    "SugarRushStart": (97618360152295137461415372663552371521, 0, 0),
    "GoldRushWarning": (273532744158899558150941731045273226810, 0, 0),
    "GoldRushStart": (174055715559403950645919247399189814292, 0, 0),
    "FlickerWarning": (293893327554777917356853587435393219884, 0, 0),
    "FlickerStart": (324204688190000373448532529058630776475, 0, 0),
    "BloodMoonWarning": (18591976466092328302252927176881050027, 0, 0),
    "WatcherAwakensWarning": (138495672242948090845689909109801829887, 0, 0),
    "WatcherAwakensStart": (294825167145047299783056444707968220047, 0, 0),
    "EventEnd": (261310662143875347988620667263380529450, 0, 0),
    "Thunder": (175492745243780518409073843892030032823, 0, 0),
    "FrostFog": (54625636869832943630459843356585606087, 0, 0),
    "SugarRush": (315939851298089173177605725354231658393, 1, 1771602223),
    "GoldRush": (254997078598393388880328317970523957418, 1, 2672971746),
    "WatcherAwakens": (189870864784255521201730970769586460453, 1, 2672971746),
    "MusicMountainKing": (283070765951860029914347476084439014823, 1, 2672971746),
}
APPROVED_INC = 300095300155318575761469457844978717175


def reseed(key):
    import zlib

    if key in APPROVED:
        value, has_uint32, uinteger = APPROVED[key]
        state = {"state": value, "inc": APPROVED_INC}
    else:
        state, has_uint32, uinteger = np.random.PCG64(zlib.crc32(key.encode())).state["state"], 0, 0
    rng.bit_generator.state = {"bit_generator": "PCG64", "state": state, "has_uint32": has_uint32, "uinteger": uinteger}


GAP = 1.0  # seconds of silence between sounds on a sheet, so a slice never catches its neighbour


def wav_write(path, sig):
    from scipy.io import wavfile

    wavfile.write(path, RATE, (np.clip(sig, -1, 1) * 32767).astype(np.int16))


def encode(sig, path_no_ext, ogg=True, mp3=True):
    wav = path_no_ext + ".wav"
    wav_write(wav, sig)
    if ogg:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", path_no_ext + ".ogg"], check=True)
    if mp3:
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libmp3lame", "-b:a", "128k", path_no_ext + ".mp3"], check=True)
    os.remove(wav)


def finish(buffer, decay=2.0, mix=0.3, rms=-17):
    return loudness(trim_tail(reverb(buffer, decay, mix)), rms)


# ================================================================ stingers


def frost_fog_warning():
    d = 6.0
    buf = silence(d + 1)
    wind = np.zeros(samples(d))
    for center, width, gain in [(500, 90, 0.5), (1150, 120, 0.35), (2300, 200, 0.18)]:
        band = looped_band(d, center, width)
        wind += band * gain * lfo(d, 2, rng.uniform(0, 6), 0.3, 1)
    wind = fade(wind * np.linspace(0.15, 1, len(wind)) ** 1.5, 0.5, 1.5)
    place(buf, stereo(wind * 0.5, -0.2), 0)
    place(buf, stereo(wind[::-1] * 0.3, 0.4), 0)
    for i, n in enumerate(["E6", "B5", "G5", "E5", "D#5", "B4"]):
        place(buf, stereo(celesta(note(n), 3.0) * 0.35, -0.5 + i * 0.2), 1.2 + i * 0.55)
    place(buf, stereo(crack(0.6) * 0.25, 0.6), 4.6)
    return finish(buf, 3.5, 0.45)


def frost_fog_start():
    d = 4.0
    buf = silence(d + 1)
    place(buf, stereo(crack(1.0) * 1.2, -0.3), 0)
    place(buf, stereo(crack(1.0) * 0.8, 0.4), 0.09)
    place(buf, boom(3.0, 50) * 0.8, 0)
    place(buf, stereo(whoosh(2.0, 400, 6000, rise=False) * 0.7), 0.05)
    for i, n in enumerate(["E5", "G5", "B5", "F#6", "B6"]):
        place(buf, stereo(bell(note(n), 3.5, 0.6) * 0.4, -0.6 + i * 0.3), 0.08 + i * 0.03)
    return finish(buf, 3.0, 0.4, -15)


def sugar_rush_warning():
    d = 5.0
    buf = silence(d + 1)
    run = ["C6", "E6", "G6", "A6", "C7", "A6", "G6", "E6", "C6", "E6", "G6", "A6", "C7"]
    for i, n in enumerate(run):
        place(buf, stereo(music_box(note(n), 2.0, wobble=0.008) * 0.45, -0.4 + 0.07 * i), 0.2 + i * 0.18)
    for _ in range(14):
        at = rng.uniform(0.3, 4.2)
        place(buf, stereo(pop(rng.uniform(200, 400), rng.uniform(800, 1500)) * 0.35, rng.uniform(-0.8, 0.8)), at)
    t = times(0.9)  # a slide up, like a toy whistle
    f = 600 * 3 ** (t / 0.9)
    slide = np.sin(2 * np.pi * np.cumsum(f) / RATE) * envelope(len(t), 0.05, release=0.2) * 0.18
    place(buf, stereo(slide, 0.2), 3.9)
    return finish(buf, 2.0, 0.3)


def sugar_rush_start():
    d = 3.5
    buf = silence(d + 1)
    for i in range(6):
        place(buf, stereo(pop(250 + i * 40, 1200 + i * 150) * 0.7, -0.6 + i * 0.25), i * 0.07)
    gliss = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6", "G6", "A6", "C7", "E7"]
    for i, n in enumerate(gliss):
        place(buf, stereo(celesta(note(n), 1.5) * 0.3, -0.5 + i * 0.09), 0.35 + i * 0.035)
    for n in ["C5", "E5", "G5", "A5", "C6"]:
        place(buf, stereo(music_box(note(n), 3.0, 0.006) * 0.4), 0.8)
    fizz = highpass(noise(2.5), 5000) * np.exp(-times(2.5) * 1.5) * 0.05
    place(buf, stereo(fizz), 0.3)
    return finish(buf, 2.0, 0.3, -15)


def gold_rush_warning():
    d = 5.0
    buf = silence(d + 1)
    for i in range(40):
        at = 0.2 + (i / 40) ** 0.7 * 3.8 + rng.uniform(0, 0.08)
        gain = 0.08 + 0.3 * (i / 40)
        place(buf, stereo(clink() * gain, rng.uniform(-0.9, 0.9)), at)
    for i, n in enumerate(["A4", "C#5", "E5", "A5"]):
        place(buf, stereo(bell(note(n), 3.0, 0.8) * 0.3, -0.3 + i * 0.2), 1.6 + i * 0.7)
    return finish(buf, 2.5, 0.35)


def gold_rush_start():
    d = 3.5
    buf = silence(d + 1)
    for _ in range(60):
        place(buf, stereo(clink() * rng.uniform(0.2, 0.55), rng.uniform(-1, 1)), abs(rng.normal(0.25, 0.35)))
    place(buf, stereo(bell(note("E6"), 2.5, 1.2) * 0.6, -0.2), 0.0)
    place(buf, stereo(bell(note("A6"), 3.0, 1.2) * 0.6, 0.2), 0.12)
    brass = np.zeros(samples(2.6))
    for n in ["A3", "E4", "A4", "C#5", "E5"]:
        brass += saw_stack(note(n), 2.6, voices=3, detune=0.004, cutoff=2600) * 0.3
    brass *= envelope(len(brass), 0.12, 0.4, 0.6, 1.2)
    place(buf, stereo(brass * 0.7), 0.15)
    return finish(buf, 2.2, 0.3, -15)


def flicker_warning():
    d = 6.0
    buf = silence(d + 1)
    h = hum(120, d) * np.linspace(0.2, 1, samples(d))
    gate = np.ones(samples(d))
    t = 0.8
    while t < d - 1.2:  # the light cuts out, more and more often
        length = rng.uniform(0.03, 0.18)
        gate[samples(t) : samples(t + length)] = 0.05
        t += rng.uniform(0.08, 0.6) * (1 - t / d) + 0.05
    gate = lowpass(gate, 120, 1)
    # power-down at the end: the hum drops in pitch and dies
    down_t = times(1.4)
    f = 120 * (1 - 0.7 * down_t / 1.4)
    down = np.sin(2 * np.pi * np.cumsum(f) / RATE)
    down = bandpass(sum(np.sin(2 * np.pi * np.cumsum(f * k) / RATE) / k for k in range(1, 12)), 50, 3000) * 0.2
    down *= np.linspace(1, 0, len(down)) ** 2
    hum_part = (h * gate)[: samples(d - 1.4)]
    place(buf, stereo(hum_part * 0.9, -0.1), 0)
    place(buf, stereo(down * 0.9, -0.1), d - 1.4)
    for _ in range(10):
        at = rng.uniform(0.5, d - 1.5)
        place(buf, stereo(crack(0.25) * 0.25, rng.uniform(-0.7, 0.7)), at)
    return finish(buf, 1.6, 0.25)


def flicker_start():
    d = 4.5
    buf = silence(d + 1)
    place(buf, stereo(thunder(4.5, near=True) * 0.9), 0)
    zap = highpass(noise(0.3), 2000) * np.exp(-times(0.3) * 12) * (0.6 + 0.4 * np.sign(np.sin(2 * np.pi * 37 * times(0.3))))
    place(buf, stereo(zap * 0.5, 0.4), 0)
    return finish(buf, 2.5, 0.3, -14)


def blood_moon_warning():
    d = 7.0
    buf = silence(d + 1)
    drone = (pad(note("Bb1"), d, 2.5, 1.5, 500) + pad(note("F2"), d, 3.0, 1.5, 600) * 0.7) * np.linspace(0.3, 1, samples(d))
    place(buf, stereo(drone * 0.6), 0)
    for i, at in enumerate([0.3, 1.25, 2.3, 3.45, 4.7]):
        place(buf, heartbeat(0.9 + i * 0.05), at)
    place(buf, stereo(howl(3.2, 400) * 0.45, 0.6), 3.4)
    return finish(buf, 3.0, 0.4)


def blood_moon_start():
    """The opening of Chopin's Funeral March (Piano Sonata No. 2, 1839): the slow rocking
    chords in the bass and the famous tune on top, played heavy and low."""
    beat = 0.92
    buf = silence(beat * 8 + 5)
    place(buf, boom(4.0, 38) * 0.45, 0)
    # the left hand rocks between B-flat minor and G-flat over B-flat, on every beat
    for i in range(8):
        chord = ["Bb1", "F2", "Db3"] if i % 2 == 0 else ["Bb1", "Gb2", "Db3"]
        for n in chord:
            place(buf, stereo(soft_piano(note(n), beat * 1.6) * 0.32, -0.2), i * beat)
        place(buf, stereo(organ(note(chord[0]), beat * 1.05, (0.8, 0.5, 0.2, 0.1, 0.0, 0.0), 0.7, 0.08) * 0.35), i * beat)
    # the tune: Bb, Bb.Bb, Bb | Db.C, C.Bb, Bb.A, Bb
    tune = [
        ("Bb3", 0, 1), ("Bb3", 1, 0.75), ("Bb3", 1.75, 0.25), ("Bb3", 2, 2),
        ("Db4", 4, 0.75), ("C4", 4.75, 0.25), ("C4", 5, 0.75), ("Bb3", 5.75, 0.25),
        ("Bb3", 6, 0.75), ("A3", 6.75, 0.25), ("Bb3", 7, 1.5),
    ]
    for name, at, length in tune:
        f = note(name)
        for octave, gain in [(1, 0.55), (2, 0.4)]:  # in octaves, like the piano's right hand
            place(buf, stereo(soft_piano(f * octave, length * beat + 1.2) * gain, 0.15), at * beat)
        place(buf, stereo(bell(f * 2, 2.5, 0.4) * 0.08, 0.3), at * beat)
    choir_part = choir([note("Bb2"), note("F3"), note("Db4")], beat * 8 + 1.5, "oh")
    place(buf, stereo(choir_part * 0.35), 0.2)
    return finish(buf, 3.0, 0.4, -16)


def watcher_warning():
    d = 7.0
    buf = silence(d + 1)
    t = times(d)
    rumble = lowpass(noise(d), 90, 2) * 3 * np.linspace(0.1, 1, len(t)) ** 2
    place(buf, stereo(rumble * 0.8), 0)
    # a cluster of strings sliding up, out of tune with itself
    for i, base in enumerate([110, 116.5, 123.5, 155.6]):
        rise = base * (1 + 0.5 * (t / d) ** 2)
        phase = 2 * np.pi * np.cumsum(rise) / RATE
        tone = sum(np.sin(phase * k) / k for k in range(1, 18))
        tone = lowpass(tone, 1500) * envelope(len(t), 2.5, release=0.6) * 0.08
        place(buf, stereo(tone, -0.6 + i * 0.4), 0)
    for _ in range(9):
        place(buf, stereo(whisper(rng.uniform(0.6, 1.2)) * 0.6, rng.uniform(-1, 1)), rng.uniform(0.5, 6))
    beat = 0.9
    at = 1.0
    while at < d - 0.3:  # the heart speeds up
        place(buf, heartbeat(1.0), at)
        beat *= 0.86
        at += max(beat, 0.38)
    return finish(buf, 2.5, 0.35)


def watcher_start():
    """The opening of Bach's Toccata in D minor (BWV 565, around 1705) on a big organ."""
    d = 15.0
    buf = silence(d + 1)
    full = (1.0, 0.8, 0.55, 0.45, 0.3, 0.25)

    def phrase(start, octave):
        def n(name):
            return note(name[:-1] + str(int(name[-1]) + octave))

        at = start
        for name, length in [("A5", 0.11), ("G5", 0.11), ("A5", 1.5)]:
            place(buf, stereo(organ(n(name), length + 0.05, full, 0.6)), at)
            at += length
        at += 0.35
        for name, length in [("G5", 0.13), ("F5", 0.13), ("E5", 0.13), ("D5", 0.13), ("C#5", 0.55), ("D5", 1.3)]:
            place(buf, stereo(organ(n(name), length + 0.05, full, 0.6)), at)
            at += length
        return at + 0.3

    at = phrase(0.0, 0)
    at = phrase(at, -1)
    pedal = note("D2")
    place(buf, stereo(organ(pedal, 1.2, full, 1.0) * 0.9), at)
    place(buf, stereo(organ(pedal / 2, 4.6, full, 1.0) * 0.8), at + 1.2)
    # the rolled diminished chord over the low D, resolving to D minor
    for i, name in enumerate(["C#3", "E3", "G3", "Bb3", "C#4", "E4"]):
        place(buf, stereo(organ(note(name), 2.6 - i * 0.12, full, 0.3) * 0.55, -0.5 + i * 0.2), at + 1.2 + i * 0.12)
    for name in ["D3", "F3", "A3", "D4", "F4", "A4"]:
        place(buf, stereo(organ(note(name), 1.9, full, 0.3) * 0.5), at + 3.9)
    return finish(buf, 4.0, 0.45, -15)


def event_end():
    d = 3.5
    buf = silence(d + 1)
    place(buf, stereo(whoosh(1.6, 300, 3000, rise=False) * 0.4), 0)
    place(buf, stereo(music_box(note("A5"), 2.5) * 0.4, -0.2), 0.7)
    place(buf, stereo(music_box(note("D6"), 2.8) * 0.4, 0.2), 1.05)
    return finish(buf, 2.5, 0.4, -19)


def thunder_hit():
    d = 4.0
    buf = silence(d + 1)
    place(buf, stereo(thunder(d, near=rng.uniform() < 0.5) * 0.9, rng.uniform(-0.4, 0.4)), 0)
    return finish(buf, 2.5, 0.3, -16)


STINGERS = [
    ("FrostFogWarning", frost_fog_warning),
    ("FrostFogStart", frost_fog_start),
    ("SugarRushWarning", sugar_rush_warning),
    ("SugarRushStart", sugar_rush_start),
    ("GoldRushWarning", gold_rush_warning),
    ("GoldRushStart", gold_rush_start),
    ("FlickerWarning", flicker_warning),
    ("FlickerStart", flicker_start),
    ("BloodMoonWarning", blood_moon_warning),
    ("BloodMoonStart", blood_moon_start),
    ("WatcherAwakensWarning", watcher_warning),
    ("WatcherAwakensStart", watcher_start),
    ("EventEnd", event_end),
    ("Thunder", thunder_hit),
]

# ================================================================ ambience loops
# Each loop is exactly LOOP seconds and wraps round on itself (noise, wobbles, reverb tails),
# so it repeats with no seam.

LOOP = 24.0


def looped(buf, decay=2.5, mix=0.35, rms=-24):
    return loudness(reverb(buf, decay, mix, wrap=True), rms)


def frost_fog_loop():
    d = LOOP
    buf = silence(d)
    for center, width, gain, pan in [(420, 80, 0.5, -0.5), (900, 110, 0.4, 0.4), (1700, 160, 0.22, -0.1), (2600, 240, 0.1, 0.6)]:
        band = looped_band(d, center, width) * gain * lfo(d, rng.integers(2, 5), rng.uniform(0, 6), 0.15, 1)
        place(buf, stereo(band, pan), 0)
    place(buf, stereo(looped_noise(d, 150, 900, -3) * 0.12), 0)
    for i in range(9):
        n = rng.choice(["E6", "B6", "G6", "F#6", "D7"])
        place(buf, stereo(celesta(note(n), 2.5) * 0.12, rng.uniform(-0.8, 0.8)), i * d / 9 + rng.uniform(0, 1.5), wrap=True)
    return looped(buf, 3.5, 0.4, -25)


def sugar_rush_loop():
    d = LOOP
    buf = silence(d)
    place(buf, stereo(looped_noise(d, 4000, 12000) * 0.03 * lfo(d, 6, 0, 0.5, 1)), 0)
    for _ in range(70):
        place(buf, stereo(pop(rng.uniform(180, 400), rng.uniform(700, 1600)) * rng.uniform(0.1, 0.3), rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
    scale = ["C5", "D5", "E5", "G5", "A5", "C6", "D6", "E6"]
    for i in range(16):
        place(buf, stereo(music_box(note(rng.choice(scale)), 2.0, 0.009) * 0.2, rng.uniform(-0.6, 0.6)), i * 1.5, wrap=True)
    return looped(buf, 2.0, 0.35, -25)


def gold_rush_loop():
    d = LOOP
    buf = silence(d)
    shimmer = looped_noise(d, 6000, 14000) * 0.02 * lfo(d, 4, 1, 0.3, 1)
    place(buf, stereo(shimmer), 0)
    for i, n in enumerate(["A3", "E4", "A4", "C#5"]):
        tone = additive(loop_freq(note(n), d), d, [(1, 1, 0), (2, 0.3, 0), (3, 0.1, 0)]) * lfo(d, 2 + i % 2, i, 0.2, 1) * 0.05
        place(buf, stereo(tone, -0.4 + i * 0.25), 0)
    for _ in range(55):
        place(buf, stereo(clink() * rng.uniform(0.05, 0.25), rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
    return looped(buf, 2.5, 0.35, -25)


def rain(d, darkness=0.0, density=1.0):
    """Rain built from thousands of single drops: tiny splashes, the odd bubbly plink, and a
    soft wash underneath. darkness lowers it all (heavy, thick Blood Moon rain)."""
    buf = silence(d)
    low = 1 - darkness * 0.45
    wash = looped_noise(d, 120, 2600 * low, -6) * 0.07 * lfo(d, 3, 0.5, 0.7, 1)
    place(buf, stereo(wash, -0.4), 0)
    place(buf, stereo(looped_noise(d, 120, 2600 * low, -6) * 0.07 * lfo(d, 2, 2.0, 0.7, 1), 0.4), 0)
    splats = []
    for _ in range(48):  # a bank of splashes to pick from
        length = rng.uniform(0.004, 0.012)
        center = rng.uniform(900, 4200) * low
        s = bandpass(noise(length + 0.01), center * 0.6, center * 1.5) * np.exp(-times(length + 0.01) / (length / 3))
        splats.append(s / (np.max(np.abs(s)) + 1e-9))
    for _ in range(int(2400 * density)):
        gain = rng.uniform(0.01, 0.07) * (rng.uniform() ** 2 * 3 + 0.3)
        place(buf, stereo(splats[rng.integers(len(splats))] * gain, rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
    for _ in range(int(160 * density)):  # drops landing in puddles: a quick rising "plink"
        length = rng.uniform(0.015, 0.04)
        t = times(length)
        f0 = rng.uniform(900, 2600) * low
        plink = np.sin(2 * np.pi * np.cumsum(f0 * (1 + 1.2 * t / length)) / RATE) * np.exp(-t * 6 / length)
        place(buf, stereo(plink * rng.uniform(0.015, 0.06), rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
    return buf


def flicker_loop():
    d = LOOP
    buf = rain(d)
    h = hum(120, d) * 0.35
    gate = np.zeros(samples(d))
    for _ in range(6):  # the buzz comes and goes
        at = rng.uniform(0, d - 3)
        length = rng.uniform(1, 2.5)
        gate[samples(at) : samples(at + length)] = 1
    gate = lowpass(gate, 6, 1) * (1 - 0.8 * (looped_noise(d, 5, 40) > 1.5))
    place(buf, stereo(h * gate, 0.5), 0)
    for _ in range(3):  # distant rumbles; the close thunder comes with the lightning flashes
        place(buf, stereo(thunder(4.0, near=False) * 0.35, rng.uniform(-0.6, 0.6)), rng.uniform(0, d), wrap=True)
    return looped(buf, 1.8, 0.25, -24)


def blood_moon_loop():
    d = LOOP
    buf = rain(d, darkness=0.6, density=1.3)
    buf *= 0.8
    for n, g in [("Bb1", 0.10), ("F2", 0.07), ("Db3", 0.03)]:
        tone = additive(loop_freq(note(n), d), d, [(1, 1, 0), (2, 0.5, 0), (3, 0.25, 0), (4, 0.1, 0)]) * lfo(d, 3, rng.uniform(0, 6), 0.5, 1)
        place(buf, stereo(tone * g), 0)
    beat = d / 18
    for i in range(18):
        place(buf, heartbeat(0.55), i * beat, wrap=True)
    place(buf, stereo(howl(3.5, 380) * 0.18, -0.7), 9.0, wrap=True)
    return looped(buf, 3.0, 0.4, -24)


def watcher_loop():
    d = LOOP
    buf = silence(d)
    for n, g in [("D2", 0.5), ("A2", 0.3), ("D3", 0.15), ("Eb3", 0.05)]:
        drone = additive(loop_freq(note(n), d), d, [(1, 1, 0), (2, 0.6, 0), (3, 0.35, 0), (4, 0.2, 0), (6, 0.1, 0)])
        place(buf, stereo(drone * g * 0.06 * lfo(d, 2, rng.uniform(0, 6), 0.6, 1)), 0)
    for i in range(4):  # a deep bell tolls
        place(buf, stereo(bell(note("D2"), 6.0, 0.5) * 0.35), i * d / 4, wrap=True)
    for _ in range(10):
        place(buf, stereo(whisper(rng.uniform(0.7, 1.3)) * 0.25, rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
    for i in range(24):
        place(buf, heartbeat(0.45), i * d / 24, wrap=True)
    return looped(buf, 4.0, 0.45, -24)


AMBIENCE = [
    ("FrostFog", frost_fog_loop),
    ("SugarRush", sugar_rush_loop),
    ("GoldRush", gold_rush_loop),
    ("Flicker", flicker_loop),
    ("BloodMoon", blood_moon_loop),
    ("WatcherAwakens", watcher_loop),
]

# ================================================================ music
# Our own arrangements of public-domain pieces. The scores are long out of copyright and the
# "performance" is this code, so there is no recording anyone else owns.


def oompah(buf, at, bass, chord, beat, gain=1.0):
    """A waltz bar's left hand: the bass on 1, the chord on 2 and 3."""
    place(buf, stereo(soft_piano(note(bass), beat * 3 + 0.8) * 0.4 * gain, -0.25), at)
    for b in (1, 2):
        for i, n in enumerate(chord):
            place(buf, stereo(celesta(note(n), 0.9) * 0.07 * gain, 0.1 + 0.1 * i), at + b * beat)


WALTZ_CHORDS = {
    "Am": ("A2", ["C4", "E4", "A4"]),
    "E7": ("E2", ["D4", "E4", "G#4"]),
    "Dm": ("D2", ["D4", "F4", "A4"]),
    "F": ("F2", ["C4", "F4", "A4"]),
    "C": ("C3", ["C4", "E4", "G4"]),
}
# An original waltz (ours, not anyone else's): four 8-bar phrases. Each bar: chord and the
# tune as (beat, note, beats).
WALTZ = [
    ("Am", [(0, "E5", 2), (2, "C5", 1)]), ("Am", [(0, "A4", 3)]),
    ("E7", [(0, "G#4", 1), (1, "B4", 1), (2, "D5", 1)]), ("E7", [(0, "F5", 2), (2, "E5", 1)]),
    ("E7", [(0, "D5", 1), (1, "C5", 1), (2, "B4", 1)]), ("E7", [(0, "G#4", 2), (2, "B4", 1)]),
    ("Am", [(0, "A4", 1), (1, "C5", 1), (2, "E5", 1)]), ("Am", [(0, "A5", 3)]),
    ("Am", [(0, "A5", 2), (2, "G5", 1)]), ("Am", [(0, "E5", 3)]),
    ("Dm", [(0, "F5", 1), (1, "E5", 1), (2, "D5", 1)]), ("Dm", [(0, "A4", 3)]),
    ("Am", [(0, "C5", 1), (1, "E5", 1), (2, "A5", 1)]), ("E7", [(0, "G#5", 2), (2, "B4", 1)]),
    ("Am", [(0, "C5", 1), (1, "B4", 1), (2, "G#4", 1)]), ("Am", [(0, "A4", 3)]),
    ("F", [(0, "C5", 1), (1, "F5", 1), (2, "A5", 1)]), ("F", [(0, "A5", 2), (2, "G5", 1)]),
    ("C", [(0, "E5", 1), (1, "G5", 1), (2, "C6", 1)]), ("C", [(0, "C6", 2), (2, "B5", 1)]),
    ("Dm", [(0, "A5", 1), (1, "F5", 1), (2, "D5", 1)]), ("Dm", [(0, "F5", 2), (2, "E5", 1)]),
    ("E7", [(0, "E5", 1), (1, "D5", 1), (2, "B4", 1)]), ("E7", [(0, "G#4", 2), (2, "E5", 1)]),
    ("Am", [(0, "A5", 2), (2, "G5", 1)]), ("Am", [(0, "E5", 3)]),
    ("Dm", [(0, "F5", 1), (1, "E5", 1), (2, "D5", 1)]), ("Dm", [(0, "A4", 3)]),
    ("Am", [(0, "C5", 1), (1, "E5", 1), (2, "A5", 1)]), ("E7", [(0, "G#5", 2), (2, "B4", 1)]),
    ("Am", [(0, "C5", 1), (1, "B4", 1), (2, "G#4", 1)]), ("Am", [(0, "A4", 3)]),
]


def music_waltz():
    """The Haunted Waltz, our own tune: a music box waltzing in A minor, played twice. The
    second time it's lower, slower to die away and more out of tune, over a cold pad."""
    beat = 0.6
    bar = beat * 3
    rounds = [(1.0, 0.004, 0.0), (0.5, 0.010, 1.0)]  # (pitch, wobble, pad)
    length = len(WALTZ) * bar
    d = len(rounds) * length + bar * 2 + 5
    buf = silence(d)
    for r, (shift, wobble, pad_gain) in enumerate(rounds):
        base = r * length
        for b, (name, tune) in enumerate(WALTZ):
            at = base + b * bar
            bass, chord = WALTZ_CHORDS[name]
            oompah(buf, at, bass, chord, beat)
            if pad_gain:
                place(buf, stereo(pad(note(chord[1]), bar + 0.6, 0.3, 0.6, 700) * 0.1 * pad_gain), at)
            for beat_at, n, beats in tune:
                f = note(n) * shift * 2
                place(buf, stereo(music_box(f, max(2.0, beats * beat + 1.0), wobble) * 0.45, 0.1), at + beat_at * beat)
    end = len(rounds) * length  # a last low A to finish
    place(buf, stereo(soft_piano(note("A1"), 4.0) * 0.45), end)
    place(buf, stereo(music_box(note("A4"), 4.0, 0.012) * 0.4, 0.1), end)
    return loudness(trim_tail(reverb(buf, 3.0, 0.4, 5000)), -19)


LULLABY_CHORDS = {
    "Dm": ["D2", "A2", "D3", "F3", "D3", "A2"],
    "Gm": ["G2", "D3", "G3", "Bb3", "G3", "D3"],
    "A7": ["A2", "E3", "G3", "C#4", "G3", "E3"],
    "Bb": ["Bb1", "F2", "Bb2", "D3", "Bb2", "F2"],
    "F": ["F2", "C3", "F3", "A3", "F3", "C3"],
}
# An original lullaby (ours) in 6/8: each bar is six eighths, the tune as (eighth, note, eighths).
LULLABY_A = [
    ("Dm", [(0, "A4", 3), (3, "F4", 2), (5, "E4", 1)]), ("Dm", [(0, "D4", 6)]),
    ("Gm", [(0, "D4", 2), (2, "G4", 1), (3, "Bb4", 3)]), ("Gm", [(0, "A4", 3), (3, "G4", 3)]),
    ("A7", [(0, "E4", 2), (2, "F4", 1), (3, "G4", 2), (5, "E4", 1)]), ("A7", [(0, "C#5", 3), (3, "A4", 3)]),
    ("Dm", [(0, "D5", 2), (2, "C5", 1), (3, "A4", 2), (5, "F4", 1)]), ("Dm", [(0, "D4", 6)]),
]
LULLABY_B = [
    ("Bb", [(0, "F4", 2), (2, "G4", 1), (3, "Bb4", 3)]), ("Bb", [(0, "D5", 3), (3, "C5", 3)]),
    ("F", [(0, "A4", 2), (2, "C5", 1), (3, "F5", 3)]), ("F", [(0, "E5", 3), (3, "C5", 3)]),
    ("Gm", [(0, "D5", 2), (2, "Bb4", 1), (3, "G4", 3)]), ("A7", [(0, "E5", 2), (2, "C#5", 1), (3, "A4", 3)]),
    ("Dm", [(0, "F5", 3), (3, "E5", 2), (5, "C#5", 1)]), ("Dm", [(0, "D5", 6)]),
]


def music_lullaby():
    """Lullaby for the Lost, our own tune: a slow rocking lullaby in D minor on a celesta,
    with the tune passing to a wonky music box the second time."""
    eighth = 0.3
    bar = eighth * 6
    form = [(LULLABY_A, 1.0, False), (LULLABY_B, 1.0, False), (LULLABY_A, 2.0, True), (LULLABY_B, 1.0, True)]
    d = sum(len(section) for section, _, _ in form) * bar + 6
    buf = silence(d)
    at = 0.0
    for section, octave, box in form:
        for name, tune in section:
            for k, n in enumerate(LULLABY_CHORDS[name]):
                place(buf, stereo(soft_piano(note(n), 1.4) * 0.16, -0.3 + 0.1 * (k % 3)), at + k * eighth)
            for start, n, length in tune:
                f = note(n) * octave
                if box:
                    place(buf, stereo(music_box(f, max(2.0, length * eighth + 1.0), 0.008) * 0.4, 0.15), at + start * eighth)
                else:
                    place(buf, stereo(celesta(f, max(1.8, length * eighth + 0.8)) * 0.5, 0.15), at + start * eighth)
            at += bar
    place(buf, stereo(pad(note("D3"), d - 4, 4.0, 3.0, 500) * 0.06), 0)
    place(buf, stereo(soft_piano(note("D2"), 4.0) * 0.4), at)
    return loudness(trim_tail(reverb(buf, 3.2, 0.42, 4500)), -20)


def music_moonlight():
    """After Beethoven, Moonlight Sonata, first movement (1801): the slow rolling triplets in
    C-sharp minor, deep octaves in the bass and the lonely tune on top."""
    triplet = 0.36
    bar = triplet * 12
    # (bass, [(triplet chord, how many)], tune: [(beat in triplets, note, length in triplets)])
    bars = [
        ("C#2", [("G#3 C#4 E4", 4)], []),
        ("B1", [("G#3 C#4 E4", 4)], []),
        (("A1", "F#1"), [("A3 C#4 E4", 2), ("A3 D4 F#4", 2)], []),
        ("G#1", [("G#3 C4 F#4", 1), ("G#3 C#4 E4", 1), ("G#3 C#4 D#4", 1), ("F#3 C4 D#4", 1)], []),
        ("C#2", [("E3 G#3 C#4", 4)], [(9, "G#4", 2.25), (11.25, "G#4", 0.75)]),
        ("C2", [("D#3 F#3 C4", 4)], [(0, "G#4", 9), (9, "G#4", 2.25), (11.25, "G#4", 0.75)]),
        ("C#2", [("E3 G#3 C#4", 2), ("E3 A3 C#4", 2)], [(0, "G#4", 6), (6, "A4", 6)]),
        ("C#2", [("F#3 A3 C#4", 2), ("F#3 A3 D#4", 2)], [(0, "G#4", 6), (6, "F#4", 6)]),
        ("B1", [("E3 G#3 B3", 2), ("D#3 F#3 B3", 2)], [(0, "E4", 6), (6, "F#4", 3), (9, "D#4", 3)]),
        ("E2", [("E3 G#3 B3", 4)], [(0, "E4", 12)]),
        ("A1", [("E3 A3 C#4", 2), ("F#3 A3 D4", 2)], [(0, "C#4", 6), (6, "D4", 6)]),
        ("G#1", [("G#3 C4 F#4", 1), ("G#3 C#4 E4", 1), ("G#3 C#4 D#4", 1), ("F#3 C4 D#4", 1)], [(0, "C#4", 6), (6, "C4", 6)]),
        ("C#2", [("G#3 C#4 E4", 4)], [(0, "C#4", 12)]),
        ("C#2", [("G#3 C#4 E4", 4)], []),
    ]
    d = len(bars) * bar + 6
    buf = silence(d)
    for b, (bass, chords, tune) in enumerate(bars):
        at = b * bar
        basses = bass if isinstance(bass, tuple) else (bass,)
        for i, bn in enumerate(basses):
            length = bar / len(basses)
            for octave in (1, 2):
                place(buf, stereo(soft_piano(note(bn) * octave, length + 1.0) * 0.3, -0.25), at + i * length)
        k = 0
        for chord, count in chords:
            names = chord.split()
            for _ in range(count * 3):
                n = names[k % 3]
                place(buf, stereo(soft_piano(note(n), 1.6) * 0.17, -0.05 + 0.1 * (k % 3)), at + k * triplet)
                k += 1
        for beat, n, length in tune:
            place(buf, stereo(soft_piano(note(n), length * triplet + 1.5) * 0.42, 0.15), at + beat * triplet)
            place(buf, stereo(celesta(note(n) * 2, 1.5) * 0.04, 0.3), at + beat * triplet)
    place(buf, stereo(pad(note("C#3"), d - 4, 4.0, 3.0, 500) * 0.06), 0)
    return loudness(trim_tail(reverb(buf, 3.5, 0.42, 4500)), -20)


def music_mountain_king():
    """After Edvard Grieg, In the Hall of the Mountain King (1875): sneaking pizzicato and
    bassoon that grows into the full band, then drops back to a whisper to loop."""
    eighth = 60 / 132 / 2
    bar = eighth * 8
    theme = [
        [("B", 1), ("C#", 1), ("D", 1), ("E", 1), ("F#", 1), ("D", 1), ("F#", 2)],
        [("F", 1), ("C#", 1), ("F", 2), ("E", 1), ("C", 1), ("E", 2)],
        [("B", 1), ("C#", 1), ("D", 1), ("E", 1), ("F#", 1), ("D", 1), ("F#", 1), ("B+", 1)],
        [("A", 1), ("F#", 1), ("D", 1), ("F#", 1), ("A", 4)],
    ]
    upper = [
        [("F#", 1), ("G#", 1), ("A#", 1), ("B", 1), ("C#+", 1), ("A#", 1), ("C#+", 2)],
        [("D+", 1), ("A#", 1), ("D+", 2), ("C#+", 1), ("A#", 1), ("C#+", 2)],
        [("F#", 1), ("G#", 1), ("A#", 1), ("B", 1), ("C#+", 1), ("A#", 1), ("C#+", 1), ("F#+", 1)],
        [("E+", 1), ("C#+", 1), ("A#", 1), ("C#+", 1), ("E+", 4)],
    ]
    bass_theme = [["B1", "F#2"], ["C#2", "F#2"], ["B1", "F#2"], ["D2", "A2"]]
    bass_upper = [["F#1", "C#2"], ["F#1", "C#2"], ["F#1", "C#2"], ["C#2", "F#2"]]

    def pitch(name, octave):
        up = name.count("+")
        return note(name.replace("+", "") + str(octave + up))

    sections = [  # (bars, bass pattern, octave, layers, loudness)
        (theme, bass_theme, 3, {"pizz"}, 0.35),
        (theme, bass_theme, 3, {"pizz", "reed"}, 0.55),
        (upper, bass_upper, 3, {"pizz", "reed", "strings"}, 0.75),
        (theme, bass_theme, 4, {"pizz", "reed", "strings", "drums", "organ"}, 1.0),
    ]
    d = len(sections) * 8 * bar
    buf = silence(d)
    at_bar = 0
    for melody, bass, octave, layers, gain in sections:
        for rep in range(2):
            for i, line in enumerate(melody):
                start = (at_bar + rep * 4 + i) * bar
                t = start
                for name, length in line:
                    f = pitch(name, octave)
                    dur = length * eighth
                    if "pizz" in layers:
                        place(buf, stereo(pluck(f, 0.6, 0.3, 0.985) * 0.45 * gain, -0.3), t, wrap=True)
                    if "reed" in layers:
                        place(buf, stereo(reed(f / 2, dur * 0.85) * 0.7 * gain, 0.2), t, wrap=True)
                    if "organ" in layers:
                        place(buf, stereo(organ(f, dur * 0.9, (0.9, 0.6, 0.4, 0.3, 0.15, 0.1), 0.3, 0.01) * 0.6 * gain), t, wrap=True)
                    t += dur
                for beat in range(4):  # the bass walks on every beat
                    bn = bass[i][beat % 2]
                    place(buf, stereo(pluck(note(bn), 0.9, 0.15, 0.99) * 0.6 * gain, 0.0), start + beat * 2 * eighth, wrap=True)
                    if "drums" in layers and beat % 2 == 0:  # soft, on beats 1 and 3 only
                        place(buf, stereo(timpani(note(bass[i][0]), 1.2, hit=0.1) * 0.18 * gain), start + beat * 2 * eighth, wrap=True)
                if "strings" in layers:
                    chord = [note(bass[i][0]) * 2, note(bass[i][1]) * 2, note(bass[i][0]) * 4]
                    for f in chord:
                        trem = pad(f, bar + 0.3, 0.2, 0.3, 2200) * (0.75 + 0.25 * np.sin(2 * np.pi * 12 * times(bar + 0.3)))
                        place(buf, stereo(trem * 0.22 * gain, 0.3), start, wrap=True)
        at_bar += 8
    # the last bar slams down and stops, then the loop starts quietly again
    end = d - bar
    place(buf, stereo(timpani(note("B1"), 2.5, hit=0.2) * 0.5), end + 4 * eighth, wrap=True)
    return loudness(reverb(buf, 2.2, 0.3, 6000, wrap=True), -18)


# The playlist, in order: the whole server hears the same song at the same moment.
MUSIC = [
    ("MusicWaltz", music_waltz),
    ("MusicMountainKing", music_mountain_king),
    ("MusicLullaby", music_lullaby),
    ("MusicMoonlight", music_moonlight),
]


# ================================================================ world ambience
# A quiet night that always plays under the music, so it never comes out of silence, and
# the little sounds that fill the pause between two songs.

NIGHT = 48.0


def cricket(pitch, chirps=3, rate=28.0):
    """One cricket chirp: a few very fast pulses of a high tone."""
    pulse = samples(1 / rate)
    out = np.zeros(pulse * chirps + samples(0.02))
    t = times(seconds(pulse))
    one = np.sin(2 * np.pi * pitch * t) * np.sin(np.pi * np.linspace(0, 1, len(t))) ** 2
    for i in range(chirps):
        out[i * pulse : i * pulse + len(one)] += one
    return out


def owl(base=370.0):
    """A soft 'hoo... hoo-hoo' far away."""
    out = np.zeros(samples(2.2))
    for at, length, bend in [(0.0, 0.55, 1.0), (0.85, 0.3, 0.97), (1.25, 0.6, 0.94)]:
        t = times(length)
        f = base * bend * (1 + 0.04 * np.sin(np.pi * t / length))
        tone = np.sin(2 * np.pi * np.cumsum(f) / RATE) + 0.15 * np.sin(4 * np.pi * np.cumsum(f) / RATE)
        tone *= np.sin(np.pi * np.linspace(0, 1, len(t))) ** 1.5
        out[samples(at) : samples(at) + len(tone)] += tone
    return lowpass(out, 1200) * 0.5


def creak(duration=1.2):
    """Old wood creaking: a stick-slip buzz whose speed wanders."""
    t = times(duration)
    rate = 40 + 70 * np.abs(np.sin(np.pi * t / duration * rng.uniform(0.8, 1.6))) + rng.uniform(-10, 10)
    phase = np.cumsum(rate) / RATE
    clicks = (np.diff(np.floor(phase), prepend=0) > 0).astype(float)
    body = signal.lfilter([1], [1, -0.97], clicks)
    tone = bandpass(body, 350, 1600)
    return tone * np.sin(np.pi * np.linspace(0, 1, len(t))) ** 0.7 * 0.6


def night_loop():
    d = NIGHT
    buf = silence(d)
    wind = 0.3  # Giles: less wind (it was 1.0)
    for center, width, gain, pan in [(380, 70, 0.22, -0.4), (820, 110, 0.12, 0.5)]:
        band = looped_band(d, center, width) * gain * wind * lfo(d, rng.integers(2, 4), rng.uniform(0, 6), 0.2, 1)
        place(buf, stereo(band, pan), 0)
    place(buf, stereo(looped_noise(d, 60, 400, -6) * 0.05 * wind), 0)
    # three crickets, each chirping in its own rhythm, now and then taking a rest
    for pitch, every, pan in [(4300, 0.62, -0.7), (4750, 0.81, 0.6), (3900, 1.13, 0.1)]:
        at = rng.uniform(0, every)
        while at < d:
            if rng.uniform() > 0.18:
                place(buf, stereo(cricket(pitch * rng.uniform(0.995, 1.005)) * 0.045, pan), at, wrap=True)
            at += every * rng.uniform(0.9, 1.1)
    place(buf, stereo(owl() * 0.18, -0.6), 9.0, wrap=True)
    place(buf, stereo(owl(345) * 0.14, 0.7), 33.0, wrap=True)
    for at in (18.0, 41.0):
        place(buf, stereo(creak(rng.uniform(0.9, 1.5)) * 0.2, rng.uniform(-0.8, 0.8)), at, wrap=True)
    place(buf, stereo(bell(note("D3"), 6.0, 0.4) * 0.07, 0.2), 26.0, wrap=True)
    # a fixed gain (what the first version was normalised to), so with less wind the crickets,
    # owl and bell stay exactly as loud as they were
    return limit(reverb(buf, 3.0, 0.4, wrap=True) * 0.397)


def wind_up():
    """A music box being wound up for the next song: the ratchet clicks, then a few notes."""
    buf = silence(4.5)
    at, gap = 0.1, 0.07
    for _ in range(26):
        click = highpass(noise(0.006), 2500) * np.exp(-times(0.006) * 600)
        tick = np.sin(2 * np.pi * 3100 * times(0.01)) * np.exp(-times(0.01) * 500) * 0.4
        place(buf, stereo(click * 0.5, -0.2), at)
        place(buf, stereo(tick, -0.2), at)
        at += gap * rng.uniform(0.9, 1.1)
        if _ % 9 == 8:
            at += 0.25  # a turn of the key
    for i, n in enumerate(["E6", "B5", "G5"]):
        place(buf, stereo(music_box(note(n), 2.2, 0.006) * 0.25, 0.2), at + 0.1 + i * 0.3)
    return loudness(trim_tail(reverb(buf, 2.0, 0.35)), -24)


def distant_toll():
    """A far-off church bell, a soft breath of wind and a whisper."""
    buf = silence(5.0)
    place(buf, stereo(whoosh(2.5, 250, 1500) * 0.1, -0.3), 0)  # Giles: less wind (was 0.35)
    place(buf, stereo(bell(note("A2"), 4.5, 0.4) * 0.5, 0.3), 0.6)
    place(buf, stereo(whisper(1.0) * 0.25, -0.7), 2.4)
    return limit(trim_tail(reverb(buf, 3.0, 0.5)) * 4.136)  # the first version's gain, bell unchanged


def creaky_house():
    """Floorboards creaking somewhere and an owl answering."""
    buf = silence(4.5)
    place(buf, stereo(creak(1.4) * 0.6, -0.5), 0.1)
    place(buf, stereo(creak(0.9) * 0.4, 0.3), 1.4)
    place(buf, stereo(owl() * 0.45, 0.6), 2.0)
    return loudness(trim_tail(reverb(buf, 2.5, 0.4)), -25)


WORLD = [
    ("Night", night_loop),
    ("WindUp", wind_up),
    ("Toll", distant_toll),
    ("Creaks", creaky_house),
]


# ================================================================ sheets


def build_sheet(entries, name, out):
    pieces, regions, at = [], {}, 0.0
    for key, make in entries:
        print("  ", key, flush=True)
        reseed(key)
        sig = make()
        encode(sig, os.path.join(out, "preview", key), ogg=False)
        length = len(sig) / RATE
        regions[key] = {"start": round(at, 3), "length": round(length, 3)}
        pieces.append(sig)
        pieces.append(silence(GAP))
        at += length + GAP
    sheet = np.vstack(pieces)
    encode(sheet, os.path.join(out, name), mp3=False)
    return regions


def main():
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(os.path.dirname(__file__), "out")
    os.makedirs(os.path.join(out, "preview"), exist_ok=True)
    print("stingers")
    stingers = build_sheet(STINGERS, "EventStingers", out)
    print("ambience")
    ambience = build_sheet(AMBIENCE, "EventAmbience", out)
    print("world")
    world = build_sheet(WORLD, "WorldAmbience", out)
    print("music")
    music = {}
    for key, make in MUSIC:
        print("  ", key, flush=True)
        reseed(key)
        sig = make()
        encode(sig, os.path.join(out, key), mp3=False)
        encode(sig, os.path.join(out, "preview", key), ogg=False)
        music[key] = round(len(sig) / RATE, 3)
    with open(os.path.join(out, "regions.json"), "w") as f:
        json.dump({"stingers": stingers, "ambience": ambience, "world": world, "music": music}, f, indent=2)
    write_luau(stingers, ambience, world, music)
    print("done:", out)


def write_luau(stingers, ambience, world, music):
    path = os.path.join(os.path.dirname(__file__), "..", "..", "src", "shared", "Config", "SoundSheets.luau")
    lines = [
        "--!strict",
        "-- GENERATED by tools/sound/make_sounds.py: don't edit by hand, re-run the script.",
        "-- Where each sound sits inside the two event sound sheets (seconds from the start of the",
        "-- file). Config/Sounds says which uploaded file is which.",
        "",
        "export type Region = { start: number, length: number }",
        "",
        "local SoundSheets = {}",
        "",
    ]
    for name, regions in [("EventStingers", stingers), ("EventAmbience", ambience), ("WorldAmbience", world)]:
        lines.append(f"SoundSheets.{name} = {{")
        for key, r in regions.items():
            lines.append(f"\t{key} = {{ start = {r['start']}, length = {r['length']} }},")
        lines.append("} :: { [string]: Region }")
        lines.append("")
    lines.append("-- The music playlist in the order it plays, with each song's length in seconds.")
    lines.append("SoundSheets.Music = {")
    for key, length in music.items():
        lines.append(f'\t{{ file = "{key}", length = {length} }},')
    lines.append("} :: { { file: string, length: number } }")
    lines.append("")
    lines.append("return SoundSheets")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
