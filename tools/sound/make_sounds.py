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
  MonsterVoices.ogg   the monsters' calls (giggles, growls, moans...), one after another
  regions.json        where each sound sits inside the sound sheets

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


# ================================================================ monster voices
# One short call per kind of monster. A monster near you makes its call now and then, from
# where it is (client/Controllers/MonsterVoiceController); Config/Sounds.MonsterVoices says
# which monster uses which call. The game plays it a little higher or lower each time, and
# lower for a bigger monster, so one call covers a whole family.


def vocal(f0, partials=40, tilt=1.0):
    """A voice-like buzz following the pitch curve f0 (one value per sample)."""
    phase = 2 * np.pi * np.cumsum(f0) / RATE
    out = np.zeros_like(f0)
    for k in range(1, partials + 1):
        out += np.sin(phase * k) / k**tilt * (f0 * k < RATE * 0.45)
    return out


def shape(src, formants):
    """Colour a buzz into a vowel: formants are (centre, gain, width) like synth.FORMANTS."""
    return sum(bandpass(src, max(40, f - w), f + w) * a for f, a, w in formants)


def curve(duration, points):
    """A pitch curve through (fraction of the way, Hz) points."""
    t = np.linspace(0, 1, samples(duration))
    xs, ys = zip(*points)
    return np.interp(t, xs, ys)


def rough(duration, rate, depth):
    """A throaty flutter: loudness shaken by low noise around `rate` Hz."""
    wobble = bandpass(noise(duration), rate * 0.6, rate * 1.6)
    return 1 + depth * wobble / (np.std(wobble) + 1e-9)


EE = [(300, 1.0, 80), (2300, 0.6, 250), (3000, 0.3, 300)]
AH = FORMANTS["ah"]
OO = FORMANTS["oo"]
OH = FORMANTS["oh"]


def syllables(buf, count, at, every, make):
    for i in range(count):
        place(buf, stereo(make(i)), at + i * every * rng.uniform(0.9, 1.1))


def glottal(f0, jitter=0.01, breath=0.15):
    """A throat: one soft pulse per period along the pitch curve f0 (Hz per sample), with a
    little pitch jitter and breath riding on each pulse, like a real voice."""
    n = len(f0)
    wobble = lowpass(rng.standard_normal(n), 30) * 8
    phase = np.cumsum(f0 * (1 + jitter * wobble)) / RATE % 1.0
    open_ = 0.6
    pulse = np.where(phase < open_, np.sin(np.pi * phase / open_) ** 2, 0.0)
    src = np.diff(pulse, prepend=0) * RATE / (f0 + 1)  # the flow's slope is what we hear
    air = highpass(rng.standard_normal(n), 400) * (0.3 + pulse) * breath
    return src + air


def resonate(x, freq, bandwidth):
    """One formant: a two-pole resonance at freq."""
    r = np.exp(-np.pi * bandwidth / RATE)
    a = [1, -2 * r * np.cos(2 * np.pi * freq / RATE), r * r]
    return signal.lfilter([1 - r], a, x)


def mouth(src, formants):
    """A vocal tract: the source through each formant (centre, gain, bandwidth) in parallel."""
    return sum(resonate(src, f, bw) * g for f, g, bw in formants)


EH = [(560, 1.0, 70), (1800, 0.55, 110), (2500, 0.35, 160), (3500, 0.12, 250)]
UH = [(450, 1.0, 70), (900, 0.45, 100), (2400, 0.12, 160)]


def voice_cackle():
    """A witch cackling: a rising 'aaah' then a fast, nasal 'heh-heh-heh-heh' tumbling down."""
    buf = silence(2.2)
    d = 0.42
    f = curve(d, [(0, 300), (0.7, 470), (1, 520)])
    f *= 1 + 0.03 * np.sin(2 * np.pi * 7 * times(d))
    ah = mouth(glottal(f, 0.02, 0.25), [(750, 1.0, 90), (1250, 0.6, 110), (2700, 0.3, 180)])
    place(buf, stereo(ah * envelope(samples(d), 0.05, release=0.08)), 0.05)
    at = 0.05 + d + 0.04
    for i in range(8):
        h = 0.085
        top = 520 - i * 22
        f = curve(h, [(0, top), (0.4, top * 1.04), (1, top * 0.86)])
        f *= 1 + 0.04 * np.sin(2 * np.pi * 18 * times(h))  # the shaky, wicked vibrato
        heh = mouth(glottal(f, 0.03, 0.35), EH)
        heh *= np.interp(times(h), [0, 0.012, 0.03, h * 0.7, h], [0, 0.4, 1, 0.8, 0])
        aspir = mouth(highpass(noise(0.03), 600), EH) * np.interp(times(0.03), [0, 0.01, 0.03], [0, 1, 0]) * 0.8
        place(buf, stereo(aspir), at)
        place(buf, stereo(heh), at + 0.015)
        at += 0.118 + i * 0.006
    return finish(buf, 1.3, 0.3, -19)


def voice_boo():
    """A little ghost: the classic airy 'wooOOOooo', swelling up and fading away."""
    d = 1.9
    f = curve(d, [(0, 260), (0.45, 400), (1, 230)])
    f *= 1 + 0.025 * np.sin(2 * np.pi * 5 * times(d))
    tone = mouth(glottal(f, 0.01, 0.9), [(320, 1.0, 60), (760, 0.35, 90), (2300, 0.05, 200)])
    whistle = np.sin(2 * np.pi * np.cumsum(f * 2) / RATE) * 0.08  # the hollow whistle in it
    sig = (tone + whistle) * np.interp(times(d), [0, 0.5, 1.0, d], [0, 0.8, 1, 0]) ** 1.3
    buf = silence(d + 0.1)
    place(buf, stereo(sig), 0.05)
    return finish(buf, 2.6, 0.5, -21)


def voice_wail():
    """A ghost lady wailing: a high 'ooo-aaah' that breaks into a sob."""
    buf = silence(2.6)
    d = 1.5
    f = curve(d, [(0, 480), (0.3, 660), (0.75, 600), (1, 430)])
    f *= 1 + 0.03 * np.sin(2 * np.pi * 6 * times(d))
    oo = mouth(glottal(f, 0.015, 0.5), [(350, 1.0, 70), (800, 0.4, 100), (2600, 0.1, 200)])
    aa = mouth(glottal(f, 0.015, 0.5), [(800, 1.0, 90), (1200, 0.55, 110), (2800, 0.25, 180)])
    mix = np.clip(times(d) / (d * 0.5), 0, 1)
    sig = (oo * (1 - mix) + aa * mix) * envelope(samples(d), 0.2, release=0.4)
    place(buf, stereo(sig), 0.05)
    for i in range(2):  # two catching sobs
        h = 0.16
        fs = curve(h, [(0, 520 - i * 40), (1, 400 - i * 40)])
        sob = mouth(glottal(fs, 0.03, 0.7), UH) * np.interp(times(h), [0, 0.02, h], [0, 1, 0])
        place(buf, stereo(sob * 0.8), 1.65 + i * 0.28)
    return finish(buf, 2.4, 0.45, -21)


def voice_gremlin():
    """A gremlin snickering: quick, high, wheezy 'hih-hih-hih-hih' through its teeth."""
    buf = silence(1.4)
    at = 0.05
    for i in range(9):
        h = 0.06
        top = 700 + 40 * np.sin(i * 1.3)
        f = curve(h, [(0, top), (1, top * 0.85)])
        hih = mouth(glottal(f, 0.03, 0.6), [(400, 0.7, 70), (2200, 1.0, 130), (3200, 0.5, 200)])
        hih *= np.interp(times(h), [0, 0.01, h * 0.6, h], [0, 1, 0.6, 0])
        hiss = bandpass(noise(0.05), 3500, 8000) * np.interp(times(0.05), [0, 0.01, 0.05], [0, 1, 0]) * 0.25
        place(buf, stereo(hiss), at)
        place(buf, stereo(hih), at + 0.01)
        at += 0.085
    return finish(buf, 1.0, 0.25, -20)


def voice_bell():
    """A drowned church bell: two slow tolls, a little muffled, with bubbles rising."""
    buf = silence(6.5)
    for i, at in enumerate((0.05, 2.2)):
        place(buf, stereo(lowpass(bell(note("C4"), 4.0, 0.8), 3500) * (1.0 - i * 0.25)), at)
    for _ in range(6):
        start = rng.uniform(200, 400)
        place(buf, stereo(pop(start, start * 3, 0.08) * 0.15), rng.uniform(0.3, 3.0))
    return finish(buf, 3.0, 0.4, -20)


def voice_flame():
    """Fire: a soft roar that flares up, with wood crackling and popping in it."""
    d = 2.0
    t = times(d)
    roar = lowpass(noise(d), 700) * (0.7 + 0.3 * lfo(d, 5, rng.uniform(0, 6)))
    roar *= np.interp(t, [0, 0.3, 0.8, d], [0, 1, 0.8, 0])
    buf = silence(d + 0.2)
    place(buf, stereo(roar * 0.5), 0.05)
    place(buf, stereo(whoosh(0.9, 200, 2500) * 0.6), 0.1)
    for _ in range(22):
        size = rng.uniform(0.002, 0.01)
        snap = highpass(noise(size), 1500) * np.exp(-times(size) * 400) * rng.uniform(0.3, 1.0)
        place(buf, stereo(snap), rng.uniform(0.1, d))
    return finish(buf, 0.8, 0.2, -21)


def voice_stone():
    """A headstone shuffling along: stone grinding on stone, then a heavy thud."""
    d = 1.0
    t = times(d)
    grind = bandpass(noise(d), 150, 1400) * rough(d, 25, 0.9)
    grind *= np.interp(t, [0, 0.1, 0.8, d], [0, 1, 0.8, 0])
    buf = silence(d + 0.8)
    place(buf, stereo(grind * 0.8), 0.05)
    thud = lowpass(noise(0.4), 220) * np.exp(-times(0.4) * 14) * 1.5
    thud += np.sin(2 * np.pi * 60 * times(0.4)) * np.exp(-times(0.4) * 10)
    place(buf, stereo(thud), d + 0.1)
    return finish(buf, 1.0, 0.25, -19)


def voice_shovel():
    """The groundskeeper digging: the shovel scrapes into the earth and dirt is tossed aside."""
    buf = silence(2.6)
    for i, at in enumerate((0.05, 1.3)):
        d = 0.35
        scrape = bandpass(noise(d), 1800, 6000) * np.interp(times(d), [0, 0.05, 0.25, d], [0, 1, 0.7, 0])
        ring = sum(np.sin(2 * np.pi * f * times(d)) * np.exp(-times(d) * 9) for f in (1730, 2940, 4410)) * 0.06
        place(buf, stereo(scrape * 0.5 + ring), at)
        place(buf, stereo(lowpass(noise(0.15), 300) * np.exp(-times(0.15) * 30) * 0.8), at + 0.3)
        for _ in range(30):  # the dirt landing
            g = rng.uniform(0.002, 0.006)
            grain = bandpass(noise(g), 400, 3000) * np.exp(-times(g) * 500) * rng.uniform(0.1, 0.5)
            place(buf, stereo(grain), at + 0.65 + abs(rng.normal(0, 0.12)))
    return finish(buf, 0.9, 0.2, -21)


def voice_popcorn():
    """Popcorn popping: a few kernels, then more and more, then it dies down."""
    buf = silence(1.8)
    times_ = sorted(rng.uniform(0.05, 1.5, 26) ** 0.9)
    for at in times_:
        d = 0.012
        kernel = highpass(noise(d), 800) * np.exp(-times(d) * 350)
        body = np.sin(2 * np.pi * rng.uniform(700, 1500) * times(0.02)) * np.exp(-times(0.02) * 180) * 0.6
        place(buf, stereo(kernel * rng.uniform(0.4, 1.0)), at)
        place(buf, stereo(body * rng.uniform(0.3, 0.8)), at)
    return finish(buf, 0.6, 0.15, -20)


def voice_balloon():
    """A sad balloon: its rubber squeaking 'eeee-ee', then a little sobbing whine of air."""
    buf = silence(1.8)
    for i, (at, d, low, high) in enumerate([(0.05, 0.45, 520, 700), (0.6, 0.25, 600, 480)]):
        f = curve(d, [(0, low), (0.6, high), (1, (low + high) / 2)])
        squeak = vocal(f, 12, 0.6) * rough(d, 60, 0.6)
        squeak = bandpass(squeak, 400, 4000) * envelope(samples(d), 0.02, release=0.08)
        place(buf, stereo(squeak * 0.6), at)
    d = 0.7
    f = curve(d, [(0, 900), (1, 650)])
    whine = np.sin(2 * np.pi * np.cumsum(f) / RATE) * 0.15 + bandpass(noise(d), 1500, 5000) * 0.1
    place(buf, stereo(whine * envelope(samples(d), 0.05, release=0.3)), 1.0)
    return finish(buf, 1.0, 0.25, -21)


def voice_jingle():
    """A jester's hat bells: a bright shake of little jingle bells."""
    buf = silence(1.6)
    for shake, start in enumerate((0.05, 0.5)):
        at = start
        for _ in range(9):
            place(buf, stereo(clink(rng.uniform(3200, 5200), 0.35) * rng.uniform(0.4, 1.0)), at)
            at += rng.uniform(0.015, 0.04)
    return finish(buf, 1.0, 0.3, -21)


def voice_glass():
    """A funhouse mirror: glass creaking and cracking, then a cold glassy ring."""
    buf = silence(2.6)
    place(buf, stereo(crack(0.6) * 0.8), 0.05)
    place(buf, stereo(crack(0.5) * 0.5), 0.35)
    ring = additive(rng.uniform(1900, 2300), 2.0, [(1, 1.0, 2.5), (2.32, 0.6, 3.5), (4.25, 0.4, 5), (6.63, 0.25, 7)])
    place(buf, stereo(ring * 0.25 * envelope(samples(2.0), 0.002, release=0.3)), 0.1)
    return finish(buf, 2.0, 0.4, -21)


def voice_tent():
    """The big top: heavy canvas flapping, and a deep rumble from inside."""
    d = 1.5
    t = times(d)
    flap = lowpass(noise(d), 1400) * (0.5 + 0.5 * np.abs(np.sin(2 * np.pi * 7 * t)) ** 3)
    flap *= np.interp(t, [0, 0.1, 1.1, d], [0, 1, 0.7, 0])
    snaps = np.zeros_like(t)
    for at in (0.2, 0.55, 0.9):
        snaps[samples(at) : samples(at) + samples(0.04)] += lowpass(noise(0.04), 2000) * np.exp(-times(0.04) * 60) * 2
    rumble = lowpass(vocal(curve(d, [(0, 55), (0.5, 65), (1, 50)]), 30, 0.8) * rough(d, 20, 0.6), 500) * 0.4
    buf = silence(d + 0.1)
    place(buf, stereo((flap * 0.5 + snaps + rumble) * envelope(len(t), 0.05, release=0.3)), 0.05)
    return finish(buf, 1.2, 0.25, -20)


def voice_carousel():
    """A carousel's tune winding down: five music-box notes that slow and sag out of tune."""
    buf = silence(3.4)
    at = 0.05
    for i, n in enumerate(["G5", "E5", "C5", "E5", "D5"]):
        sag = 1 - i * 0.025
        place(buf, stereo(music_box(note(n) * sag, 2.0, 0.01 + i * 0.004) * 0.5), at)
        at += 0.28 + i * 0.07
    return finish(buf, 2.0, 0.4, -22)


def voice_static():
    """A haunted TV: a burst of static, the mains hum, a ghostly voice in the noise, then off."""
    d = 1.4
    t = times(d)
    hiss = bandpass(noise(d), 1000, 9000) * (0.6 + 0.4 * (rng.uniform(size=len(t)) > 0.3))
    gate = np.interp(t, [0, 0.02, 1.15, 1.17, d], [0, 1, 1, 0, 0])
    buzz = hum(60, d, 0.8) * 0.8
    ghost = mouth(glottal(curve(d, [(0, 200), (0.5, 260), (1, 180)]), 0.02, 0.8), OO) * 0.5
    ghost *= np.interp(t, [0, 0.3, 0.7, 1.1, d], [0, 0, 1, 0, 0])
    buf = silence(d + 0.1)
    place(buf, stereo((hiss * 0.35 + buzz + ghost) * gate), 0.05)
    return finish(buf, 0.6, 0.15, -21)


def metal_clank(freq=420, duration=0.8):
    """Iron hitting iron: a few clashing inharmonic partials."""
    parts = [(1, 1.0, 6), (2.76, 0.7, 9), (5.4, 0.5, 14), (8.9, 0.3, 20)]
    hit = additive(freq, duration, parts) * envelope(samples(duration), 0.001, release=0.1)
    return hit * 0.4 + highpass(noise(duration), 2000) * np.exp(-times(duration) * 60) * 0.5


def voice_clank():
    """A metal mimic: a rusty lid creaking open, then snapping shut with a clank."""
    buf = silence(2.0)
    lid = highpass(creak(0.9), 600) * 1.4
    place(buf, stereo(lid), 0.05)
    place(buf, stereo(metal_clank(380)), 1.0)
    place(buf, stereo(lowpass(noise(0.2), 400) * np.exp(-times(0.2) * 25)), 1.0)
    return finish(buf, 1.0, 0.25, -20)


def voice_buzz():
    """A street lamp: its bulb buzzing and stuttering on and off, and iron creaking."""
    d = 1.6
    t = times(d)
    on = np.ones_like(t)
    for start, length in [(0.3, 0.06), (0.5, 0.03), (0.9, 0.12), (1.25, 0.04)]:
        on[samples(start) : samples(start + length)] = 0.05
    on = lowpass(on, 200)
    buf = silence(d + 0.6)
    place(buf, stereo(hum(120, d, 0.9) * on * 1.6 * envelope(len(t), 0.02, release=0.1)), 0.05)
    place(buf, stereo(highpass(creak(0.6), 400) * 0.7), d - 0.2)
    return finish(buf, 0.9, 0.2, -21)


def voice_storm():
    """A storm gremlin's cloud: a crackle of lightning and a short roll of thunder."""
    buf = silence(3.2)
    d = 0.35
    zap = highpass(noise(d), 1200) * (rng.uniform(size=samples(d)) > 0.55) * np.exp(-times(d) * 8)
    place(buf, stereo(zap * 0.6), 0.05)
    place(buf, stereo(thunder(2.6, near=False) * 0.8), 0.25)
    return finish(buf, 1.5, 0.3, -20)


def voice_knock():
    """A door that walks: three heavy knocks on old wood, and its brass knocker rattling."""
    buf = silence(2.0)
    for i in range(3):
        d = 0.25
        t = times(d)
        wood = sum(np.sin(2 * np.pi * f * t) * np.exp(-t * k) for f, k in [(110, 25), (240, 35), (520, 55)])
        wood += lowpass(noise(d), 1500) * np.exp(-t * 90) * 1.5
        place(buf, stereo(wood * (1.0 if i < 2 else 1.2)), 0.05 + i * 0.28 + (0.08 if i == 2 else 0))
    place(buf, stereo(metal_clank(900, 0.5) * 0.4), 1.05)
    place(buf, stereo(metal_clank(950, 0.4) * 0.25), 1.18)
    return finish(buf, 1.0, 0.25, -19)


def voice_squawk():
    """A heron's (or gull's) harsh croaking squawk: 'fraaank'."""
    buf = silence(1.4)
    d = 0.5
    f = curve(d, [(0, 330), (0.15, 400), (1, 260)])
    src = vocal(f, 40, 0.6) * rough(d, 55, 1.0)
    tone = shape(src, [(900, 1.0, 180), (1600, 0.8, 240), (2700, 0.4, 320)])
    place(buf, stereo(tone * envelope(samples(d), 0.01, release=0.15)), 0.05)
    return finish(buf, 1.4, 0.3, -20)


def voice_moan():
    """A ghost's long low 'ooooh', bending up and sagging away, with breath in it."""
    d = 2.2
    f = curve(d, [(0, 190), (0.3, 245), (0.65, 225), (1, 160)])
    f = f * (1 + 0.012 * np.sin(2 * np.pi * 4.3 * times(d)))
    tone = shape(vocal(f, 25, 1.2), OO) * 0.7 + shape(vocal(f * 1.005, 25, 1.2), OH) * 0.3
    breath = bandpass(noise(d), 300, 1800) * 0.08
    sig = (tone + breath) * envelope(samples(d), 0.35, release=0.8)
    buf = silence(d + 0.2)
    place(buf, stereo(sig), 0.05)
    return finish(buf, 2.6, 0.45, -21)


def voice_growl():
    """A beast's low throaty growl that swells and fades."""
    d = 1.4
    f = curve(d, [(0, 75), (0.4, 92), (1, 70)])
    src = vocal(f, 60, 0.8) * rough(d, 32, 0.7)
    tone = shape(src, [(400, 1.0, 120), (850, 0.7, 160), (2000, 0.2, 300)])
    tone += lowpass(noise(d), 300) * rough(d, 30, 0.8) * 0.15
    sig = tone * envelope(samples(d), 0.15, release=0.45) * np.interp(times(d), [0, 0.5, d], [0.7, 1, 0.8])
    buf = silence(d + 0.1)
    place(buf, stereo(sig), 0.05)
    return finish(buf, 1.2, 0.2, -19)


def voice_howl():
    """A ghostly wolf howl, far off."""
    buf = silence(2.8)
    place(buf, stereo(howl(2.4, 430)), 0.05)
    place(buf, stereo(howl(2.0, 437) * 0.25), 0.2)  # a thin double, like an echo across a valley
    return finish(buf, 2.4, 0.45, -21)


def voice_bark():
    """Two hollow ghost-dog barks: 'rowf, rowf'."""
    buf = silence(1.2)

    def rowf(i):
        d = 0.2
        f = curve(d, [(0, 330), (0.25, 420), (1, 230)])
        tone = shape(vocal(f, 40, 0.9) * rough(d, 40, 0.3), [(600, 1.0, 150), (1100, 0.6, 200), (2400, 0.2, 300)])
        burst = bandpass(noise(d), 500, 2500) * np.exp(-times(d) * 25) * 0.4
        return (tone + burst) * envelope(samples(d), 0.004, release=0.08)

    syllables(buf, 2, 0.05, 0.32, rowf)
    return finish(buf, 1.3, 0.3, -19)


def voice_caw():
    """A crow (or gull) cawing twice: 'kraa, kraa', raspy and nasal."""
    buf = silence(1.3)

    def kraa(i):
        d = 0.32 - i * 0.06
        f = curve(d, [(0, 560), (0.2, 640), (1, 470)])
        src = vocal(f, 30, 0.7) * rough(d, 80, 0.8)
        tone = shape(src, [(1200, 1.0, 200), (2100, 0.8, 250), (3300, 0.4, 350)])
        return tone * envelope(samples(d), 0.01, release=0.08)

    syllables(buf, 2, 0.05, 0.45, kraa)
    return finish(buf, 1.4, 0.3, -20)


def voice_croak():
    """A big bog frog: two slow 'rrribbit' croaks, a rattle of wet pulses."""
    buf = silence(1.3)

    def ribbit(i):
        d = 0.38
        rate = 22 if i == 0 else 26
        out = np.zeros(samples(d))
        at = 0.0
        while at < d - 0.03:
            p = 0.025
            f = 320 * (1 + 0.15 * at / d)
            pulse = np.sin(2 * np.pi * f * times(p)) + 0.5 * np.sin(2 * np.pi * 2.6 * f * times(p))
            out[samples(at) : samples(at) + samples(p)] += pulse * np.exp(-times(p) * 120)
            at += 1 / rate
        return lowpass(out, 2500) * np.interp(times(d), [0, 0.05, d], [0.4, 1, 0.5]) * 0.8

    syllables(buf, 2, 0.05, 0.55, ribbit)
    return finish(buf, 1.0, 0.2, -20)


def voice_rattle():
    """Old bones rattling: a dry clatter of little wooden knocks, shaken twice."""
    buf = silence(1.4)

    def knock():
        d = 0.03
        f = rng.uniform(1400, 3200)
        tone = np.sin(2 * np.pi * f * times(d)) + 0.6 * np.sin(2 * np.pi * f * 1.7 * times(d))
        return (tone * 0.6 + bandpass(noise(d), 1500, 5000)) * np.exp(-times(d) * rng.uniform(120, 220))

    for shake, start in enumerate((0.05, 0.6)):
        at = start
        for _ in range(16 - shake * 4):
            place(buf, stereo(knock() * rng.uniform(0.3, 1.0)), at)
            at += rng.uniform(0.012, 0.035)
    return finish(buf, 1.0, 0.25, -21)


def voice_hiss():
    """A serpent's hiss with a flick of the tongue."""
    d = 1.3
    t = times(d)
    hiss = bandpass(noise(d), 3500, 9500) * envelope(samples(d), 0.12, release=0.5)
    hiss *= 1 + 0.25 * np.sin(2 * np.pi * 9 * t) * (t > 0.6)
    buf = silence(d + 0.4)
    place(buf, stereo(hiss), 0.05)
    for i in range(3):  # the tongue flicking: three tiny ticks
        tick = highpass(noise(0.01), 4000) * np.exp(-times(0.01) * 500)
        place(buf, stereo(tick * 0.6), d + 0.05 + i * 0.07)
    return finish(buf, 1.0, 0.25, -21)


def voice_whinny():
    """A ghost horse whinnying: a high shaking cry that falls, then a snort."""
    d = 1.3
    t = times(d)
    f = curve(d, [(0, 700), (0.15, 1050), (0.6, 800), (1, 450)])
    f = f * (1 + 0.06 * np.sin(2 * np.pi * 13 * t) * np.clip(t / 0.2, 0, 1))
    tone = shape(vocal(f, 25, 1.0), [(900, 1.0, 200), (1600, 0.7, 250), (2900, 0.3, 350)])
    sig = tone * envelope(samples(d), 0.04, release=0.4)
    buf = silence(d + 0.7)
    place(buf, stereo(sig), 0.05)
    snort = bandpass(noise(0.25), 300, 2000) * envelope(samples(0.25), 0.01, release=0.15) * 0.6
    place(buf, stereo(snort), d + 0.15)
    return finish(buf, 2.0, 0.4, -21)


def voice_chime():
    """Something precious calling: three soft glassy notes falling, with a shimmer."""
    buf = silence(3.0)
    for i, n in enumerate(["E6", "B5", "G#5"]):
        place(buf, stereo(bell(note(n), 2.2, 0.6) * 0.5), 0.05 + i * 0.28)
    shimmer = sum(clink(rng.uniform(4000, 6500), 0.6) for _ in range(4)) * 0.15
    place(buf, stereo(shimmer), 0.1)
    return finish(buf, 2.5, 0.45, -22)


def voice_squeak():
    """A bat squeaking: a few tiny high chirps."""
    buf = silence(1.0)

    def chirp(i):
        d = 0.045
        f = curve(d, [(0, 4200 - i * 200), (1, 2600 - i * 150)])
        return np.sin(2 * np.pi * np.cumsum(f) / RATE) * envelope(samples(d), 0.003, release=0.02)

    syllables(buf, 4, 0.05, 0.11, chirp)
    place(buf, stereo(whoosh(0.4, 600, 3000) * 0.3), 0.45)  # a flap of leathery wings
    return finish(buf, 0.9, 0.25, -21)


def voice_creak():
    """A mimic: a lid creaking open... and snapping shut."""
    buf = silence(2.0)
    place(buf, stereo(creak(1.0) * 1.2), 0.05)
    d = 0.3
    chomp = lowpass(noise(d), 400) * np.exp(-times(d) * 25) * 1.5
    chomp += np.sin(2 * np.pi * 90 * times(d)) * np.exp(-times(d) * 18)
    chomp[: samples(0.006)] += highpass(noise(0.006), 1500) * 1.2
    place(buf, stereo(chomp), 1.15)
    return finish(buf, 1.2, 0.25, -19)


def voice_whisper():
    """The Watcher's children: two overlapping whispers over a deep hum."""
    buf = silence(2.4)
    place(buf, stereo(whisper(1.1)), 0.05)
    place(buf, stereo(whisper(0.9) * 0.8), 0.8)
    d = 2.2
    f = curve(d, [(0, 82), (1, 74)])
    hm = shape(vocal(f, 30, 1.2), OO) * envelope(samples(d), 0.6, release=0.8) * 0.5
    place(buf, stereo(hm), 0.05)
    return finish(buf, 2.8, 0.5, -21)


def voice_gurgle():
    """Something under the water: a burble of rising bubbles."""
    buf = silence(1.5)
    at = 0.05
    for i in range(14):
        start = rng.uniform(150, 350)
        place(buf, stereo(pop(start, start * rng.uniform(2.5, 4), rng.uniform(0.05, 0.1)) * rng.uniform(0.4, 1)), at)
        at += rng.uniform(0.04, 0.11)
    place(buf, stereo(lowpass(noise(1.2), 250) * envelope(samples(1.2), 0.2, release=0.5) * 0.2), 0.05)
    return finish(buf, 1.0, 0.25, -21)


VOICES = [
    ("Boo", voice_boo),
    ("Cackle", voice_cackle),
    ("Wail", voice_wail),
    ("Moan", voice_moan),
    ("Growl", voice_growl),
    ("Howl", voice_howl),
    ("Bark", voice_bark),
    ("Caw", voice_caw),
    ("Squawk", voice_squawk),
    ("Croak", voice_croak),
    ("Rattle", voice_rattle),
    ("Hiss", voice_hiss),
    ("Whinny", voice_whinny),
    ("Bell", voice_bell),
    ("Chime", voice_chime),
    ("Squeak", voice_squeak),
    ("Creak", voice_creak),
    ("Clank", voice_clank),
    ("Knock", voice_knock),
    ("Whisper", voice_whisper),
    ("Gurgle", voice_gurgle),
    ("Flame", voice_flame),
    ("Stone", voice_stone),
    ("Shovel", voice_shovel),
    ("Popcorn", voice_popcorn),
    ("Balloon", voice_balloon),
    ("Gremlin", voice_gremlin),
    ("Jingle", voice_jingle),
    ("Glass", voice_glass),
    ("Tent", voice_tent),
    ("Carousel", voice_carousel),
    ("Static", voice_static),
    ("Buzz", voice_buzz),
    ("Storm", voice_storm),
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
    print("monsters")
    voices = build_sheet(VOICES, "MonsterVoices", out)
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
        json.dump({"stingers": stingers, "ambience": ambience, "world": world, "voices": voices, "music": music}, f, indent=2)
    write_luau(stingers, ambience, world, voices, music)
    print("done:", out)


def write_luau(stingers, ambience, world, voices, music):
    path = os.path.join(os.path.dirname(__file__), "..", "..", "src", "shared", "Config", "SoundSheets.luau")
    lines = [
        "--!strict",
        "-- GENERATED by tools/sound/make_sounds.py: don't edit by hand, re-run the script.",
        "-- Where each sound sits inside the sound sheets (seconds from the start of the",
        "-- file). Config/Sounds says which uploaded file is which.",
        "",
        "export type Region = { start: number, length: number }",
        "",
        "local SoundSheets = {}",
        "",
    ]
    for name, regions in [("EventStingers", stingers), ("EventAmbience", ambience), ("WorldAmbience", world), ("MonsterVoices", voices)]:
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
