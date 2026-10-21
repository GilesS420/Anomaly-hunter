"""Render all of Anomaly Hunter's sounds.

    python tools/sound/make_sounds.py [out_dir]

Writes, into out_dir (default: tools/sound/out):
  EventStingers.ogg   every event's warning and start sound, one after another
  EventAmbience.ogg   every event's background loop, one after another
  MusicHub.ogg        hub music       (after Satie, Gymnopedie No. 1, 1888)
  MusicMansion.ogg    mansion music   (after Bach, Prelude in C major BWV 846, 1722)
  MusicZone.ogg       zone music      (after Grieg, In the Hall of the Mountain King, 1875)
  preview/*.mp3       each sound on its own, for the preview page
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
    d = 6.0
    buf = silence(d + 1)
    place(buf, boom(4.0, 40) * 0.9, 0)
    # the opening of Chopin's funeral march (Sonata No. 2, 1839): Bb, Bb.Bb, Bb
    for at, n in [(0.0, "Bb2"), (0.9, "Bb2"), (1.575, "Bb2"), (1.8, "Bb2")]:
        place(buf, stereo(bell(note(n), 4.0, 0.7) * 0.9), at)
    place(buf, stereo(choir([note("Bb3"), note("Db4"), note("F4"), note("Bb4")], 4.5, "ah") * 0.7), 0.1)
    return finish(buf, 3.5, 0.45, -15)


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


def rain(d, darkness=0.0, drops=300):
    buf = silence(d)
    place(buf, stereo(looped_noise(d, 400 - darkness * 250, 9000 - darkness * 5000, -2) * 0.25, -0.3), 0)
    place(buf, stereo(looped_noise(d, 400 - darkness * 250, 9000 - darkness * 5000, -2) * 0.25, 0.3), 0)
    for _ in range(drops):
        f = rng.uniform(1500, 4500) * (1 - darkness * 0.5)
        drip = np.sin(2 * np.pi * f * times(0.02)) * np.exp(-times(0.02) * 250)
        place(buf, stereo(drip * rng.uniform(0.05, 0.2), rng.uniform(-1, 1)), rng.uniform(0, d), wrap=True)
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
    buf = rain(d, darkness=0.6, drops=150)
    buf *= 0.6
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


def music_hub():
    """After Erik Satie, Gymnopedie No. 1 (1888): slow 3/4, music box over a soft pad."""
    beat = 60 / 68
    bar = beat * 3
    bars = 32
    d = bars * bar
    buf = silence(d)
    g, dm = (["G2"], ["B3", "D4", "F#4"]), (["D2"], ["A3", "C#4", "F#4"])
    for b in range(bars):
        bass, chord = g if b % 2 == 0 else dm
        at = b * bar
        place(buf, stereo(soft_piano(note(bass[0]), bar + 1.0) * 0.55, -0.15), at, wrap=True)
        for i, n in enumerate(chord):
            place(buf, stereo(soft_piano(note(n), bar * 0.66 + 0.8) * 0.2, 0.2 + 0.1 * i), at + beat, wrap=True)
        place(buf, stereo(pad(note(chord[1]), bar + 0.4, 0.6, 0.8, 900) * 0.18, 0.0), at, wrap=True)
    # melody: (bar, beat, note, beats)
    phrase = [
        (0, 1, "F#5", 1), (0, 2, "A5", 1),
        (1, 0, "G5", 1), (1, 1, "F#5", 1), (1, 2, "C#5", 1),
        (2, 0, "B4", 1), (2, 1, "C#5", 1), (2, 2, "D5", 1),
        (3, 0, "A4", 3),
        (4, 0, "F#4", 6),
    ]
    melody = [(4 + b, bt, n, l) for b, bt, n, l in phrase]
    melody += [(12 + b, bt, n, l) for b, bt, n, l in phrase[:-2]]
    melody += [(15, 0, "A4", 3), (16, 0, "C#5", 3), (17, 0, "F#5", 3), (18, 0, "E5", 6)]
    melody += [
        (20, 1, "B4", 1), (20, 2, "C#5", 1),
        (21, 0, "D5", 1), (21, 1, "E5", 1), (21, 2, "F#5", 1),
        (22, 0, "A5", 3),
        (23, 0, "G5", 1), (23, 1, "F#5", 1), (23, 2, "E5", 1),
        (24, 0, "F#5", 3), (25, 0, "D5", 3), (26, 0, "E5", 3), (27, 0, "C#5", 3), (28, 0, "D5", 6),
    ]
    for b, bt, n, length in melody:
        at = b * bar + bt * beat
        place(buf, stereo(music_box(note(n), max(2.5, length * beat + 1.2), wobble=0.004) * 0.5, -0.1), at, wrap=True)
        place(buf, stereo(celesta(note(n) * 2, 1.5) * 0.06, 0.3), at + 0.01, wrap=True)
    return loudness(reverb(buf, 3.2, 0.4, 5000, wrap=True), -19)


PRELUDE = [
    "C4 E4 G4 C5 E5", "C4 D4 A4 D5 F5", "B3 D4 G4 D5 F5", "C4 E4 G4 C5 E5",
    "C4 E4 A4 E5 A5", "C4 D4 F#4 A4 D5", "B3 D4 G4 D5 G5", "B3 C4 E4 G4 C5",
    "A3 C4 E4 G4 C5", "D3 A3 D4 F#4 C5", "G3 B3 D4 G4 B4", "G3 Bb3 E4 G4 C#5",
    "F3 A3 D4 A4 D5", "F3 Ab3 D4 F4 B4", "E3 G3 C4 G4 C5", "E3 F3 A3 C4 F4",
    "D3 F3 A3 C4 F4", "G2 D3 G3 B3 F4", "C3 E3 G3 C4 E4", "C3 G3 Bb3 C4 E4",
    "F2 F3 A3 C4 E4", "F#2 C3 A3 C4 Eb4", "Ab2 F3 B3 C4 D4", "G2 F3 G3 B3 D4",
    "G2 E3 G3 C4 E4", "G2 D3 G3 C4 F4", "G2 D3 G3 B3 F4", "G2 Eb3 A3 C4 F#4",
    "G2 E3 G3 C4 G4", "G2 D3 G3 C4 F4", "G2 D3 G3 B3 F4", "C2 C3 G3 Bb3 E4",
]


def music_mansion():
    """After J. S. Bach, Prelude in C major BWV 846 (1722): harp with a music box on top."""
    step = 0.2  # one sixteenth
    bar = step * 16
    bars = len(PRELUDE) + 2  # then the final chord, then a breath before it starts again
    d = bars * bar
    buf = silence(d)
    for b, chord in enumerate(PRELUDE):
        n = chord.split()
        pattern = [n[0], n[1], n[2], n[3], n[4], n[2], n[3], n[4]] * 2
        for i, name in enumerate(pattern):
            at = b * bar + i * step
            f = note(name)
            place(buf, stereo(pluck(f, 2.2, 0.35, 0.997) * 0.45, -0.3 + 0.12 * (i % 8) / 2), at, wrap=True)
            if i % 8 == 4:  # the top note, an octave up on the music box
                place(buf, stereo(music_box(f * 2, 2.0, 0.005) * 0.16, 0.35), at, wrap=True)
        place(buf, stereo(pad(note(n[0]), bar + 0.5, 0.8, 1.0, 600) * 0.12), b * bar, wrap=True)
    end = len(PRELUDE) * bar
    for i, name in enumerate(["C2", "C3", "E4", "G4", "C5"]):
        place(buf, stereo(pluck(note(name), 4.0, 0.35, 0.998) * 0.45), end + i * 0.08, wrap=True)
    place(buf, stereo(music_box(note("C6"), 4.0) * 0.25, 0.3), end + 0.4, wrap=True)
    return loudness(reverb(buf, 3.0, 0.38, 5500, wrap=True), -19)


def music_zone():
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
                        place(buf, stereo(pluck(f, 0.6, 0.6, 0.985) * 0.6 * gain, -0.3), t, wrap=True)
                    if "reed" in layers:
                        place(buf, stereo(reed(f / 2, dur * 0.85) * 0.7 * gain, 0.2), t, wrap=True)
                    if "organ" in layers:
                        place(buf, stereo(organ(f, dur * 0.9, (0.9, 0.6, 0.4, 0.3, 0.15, 0.1), 0.3, 0.01) * 0.6 * gain), t, wrap=True)
                    t += dur
                for beat in range(4):  # the bass walks on every beat
                    bn = bass[i][beat % 2]
                    place(buf, stereo(pluck(note(bn), 0.9, 0.3, 0.99) * 0.8 * gain, 0.0), start + beat * 2 * eighth, wrap=True)
                    if "drums" in layers:
                        place(buf, stereo(timpani(note(bass[i][0]), 1.2) * 0.5 * gain), start + beat * 2 * eighth, wrap=True)
                if "strings" in layers:
                    chord = [note(bass[i][0]) * 2, note(bass[i][1]) * 2, note(bass[i][0]) * 4]
                    for f in chord:
                        trem = pad(f, bar + 0.3, 0.2, 0.3, 2200) * (0.75 + 0.25 * np.sin(2 * np.pi * 12 * times(bar + 0.3)))
                        place(buf, stereo(trem * 0.22 * gain, 0.3), start, wrap=True)
        at_bar += 8
    # the last bar slams down and stops, then the loop starts quietly again
    end = d - bar
    place(buf, stereo(timpani(note("B1"), 2.5) * 0.9), end + 4 * eighth, wrap=True)
    return loudness(reverb(buf, 2.2, 0.3, 6000, wrap=True), -18)


MUSIC = [
    ("MusicHub", music_hub),
    ("MusicMansion", music_mansion),
    ("MusicZone", music_zone),
]


# ================================================================ sheets


def build_sheet(entries, name, out):
    pieces, regions, at = [], {}, 0.0
    for key, make in entries:
        print("  ", key, flush=True)
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
    print("music")
    music = {}
    for key, make in MUSIC:
        print("  ", key, flush=True)
        sig = make()
        encode(sig, os.path.join(out, key), mp3=False)
        encode(sig, os.path.join(out, "preview", key), ogg=False)
        music[key] = round(len(sig) / RATE, 3)
    with open(os.path.join(out, "regions.json"), "w") as f:
        json.dump({"stingers": stingers, "ambience": ambience, "music": music}, f, indent=2)
    write_luau(stingers, ambience)
    print("done:", out)


def write_luau(stingers, ambience):
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
    for name, regions in [("EventStingers", stingers), ("EventAmbience", ambience)]:
        lines.append(f"SoundSheets.{name} = {{")
        for key, r in regions.items():
            lines.append(f"\t{key} = {{ start = {r['start']}, length = {r['length']} }},")
        lines.append("} :: { [string]: Region }")
        lines.append("")
    lines.append("return SoundSheets")
    with open(path, "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    main()
