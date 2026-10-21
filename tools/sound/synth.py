"""Small synthesizer toolkit for Anomaly Hunter's sounds.

Everything here is built from sine waves, noise and filters, so every sound it makes is our
own: no samples, no recordings, nothing anyone else owns. make_sounds.py uses it to render
the event sound effects, the event ambience loops and the music.

Signals are numpy float arrays at RATE samples per second: mono is shape (n,), stereo is
shape (n, 2).
"""

import numpy as np
from scipy import signal

RATE = 44100
rng = np.random.default_rng(420)


def seconds(n):
    return n / RATE


def samples(duration):
    return int(round(duration * RATE))


def times(duration):
    return np.arange(samples(duration)) / RATE


def note(name):
    """'A4' -> 440.0. Sharps with #, flats with b ('Bb3', 'C#5')."""
    letters = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    semis = letters[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        semis += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    octave = int(rest)
    return 440.0 * 2 ** ((semis + (octave - 4) * 12) / 12)


# ---------------------------------------------------------------- envelopes and helpers


def envelope(n, attack=0.005, decay=0.0, sustain=1.0, release=0.05, hold=None):
    """Attack-decay-sustain-release over n samples; the release ends the sound."""
    env = np.full(n, float(sustain))
    a = min(samples(attack), n)
    d = min(samples(decay), n - a)
    r = min(samples(release), n - a - d)
    if a:
        env[:a] = np.linspace(0, 1, a, endpoint=False)
    if d:
        env[a : a + d] = np.linspace(1, sustain, d, endpoint=False)
    if r:
        env[n - r :] *= np.linspace(1, 0, r) ** 2
    return env


def fade(sig, fade_in=0.0, fade_out=0.0):
    sig = sig.copy()
    i, o = samples(fade_in), samples(fade_out)
    if i:
        sig[:i] *= np.linspace(0, 1, i)[:, None] if sig.ndim == 2 else np.linspace(0, 1, i)
    if o:
        sig[-o:] *= np.linspace(1, 0, o)[:, None] if sig.ndim == 2 else np.linspace(1, 0, o)
    return sig


def stereo(mono, pan=0.0):
    """Pan a mono signal: -1 left, 0 middle, 1 right (equal power)."""
    angle = (pan + 1) * np.pi / 4
    return np.stack([mono * np.cos(angle), mono * np.sin(angle)], axis=1)


def silence(duration):
    return np.zeros((samples(duration), 2))


def place(buffer, sig, at, gain=1.0, wrap=False):
    """Add sig into buffer starting at `at` seconds. wrap: anything past the end goes round to
    the start (for seamless loops)."""
    if sig.ndim == 1:
        sig = stereo(sig)
    start = samples(at)
    n = len(buffer)
    if wrap:
        idx = (start + np.arange(len(sig))) % n
        np.add.at(buffer, idx, sig * gain)
        return buffer
    end = min(start + len(sig), n)
    if end > start:
        buffer[start:end] += sig[: end - start] * gain
    return buffer


def normalize(sig, peak=0.89):
    top = np.max(np.abs(sig))
    return sig if top == 0 else sig * (peak / top)


def loudness(sig, rms_db):
    """Scale so the RMS sits at rms_db dBFS, then make sure nothing clips."""
    rms = np.sqrt(np.mean(sig**2))
    if rms > 0:
        sig = sig * (10 ** (rms_db / 20) / rms)
    return limit(sig)


def limit(sig, ceiling=0.8, window=0.006, release=0.08):
    """Peak limiter: sharp hits (cracks, thunder) are turned down on their own, briefly, so
    they don't force the whole sound quieter or distort."""
    from scipy.ndimage import maximum_filter1d

    level = np.max(np.abs(sig), axis=1) if sig.ndim == 2 else np.abs(sig)
    level = maximum_filter1d(level, samples(window) * 2 + 1)
    gain = np.minimum(1.0, ceiling / np.maximum(level, 1e-9))
    # recover slowly after a hit: a one-pole smoother on the gain, never above the instant need
    smooth = signal.lfilter([1 - np.exp(-1 / (release * RATE))], [1, -np.exp(-1 / (release * RATE))], gain - 1) + 1
    gain = np.minimum(gain, smooth)
    return sig * (gain[:, None] if sig.ndim == 2 else gain)


def soft_clip(sig, ceiling=0.95):
    return np.tanh(sig / ceiling) * ceiling


# ---------------------------------------------------------------- filters


def lowpass(sig, cutoff, order=2):
    b, a = signal.butter(order, min(cutoff, RATE * 0.45), "low", fs=RATE)
    return signal.lfilter(b, a, sig, axis=0)


def highpass(sig, cutoff, order=2):
    b, a = signal.butter(order, cutoff, "high", fs=RATE)
    return signal.lfilter(b, a, sig, axis=0)


def bandpass(sig, low, high, order=2):
    b, a = signal.butter(order, [low, min(high, RATE * 0.45)], "band", fs=RATE)
    return signal.lfilter(b, a, sig, axis=0)


def noise(duration):
    return rng.standard_normal(samples(duration))


def looped_noise(duration, low=20.0, high=18000.0, tilt=0.0):
    """Noise that repeats perfectly after `duration` (shaped in the frequency domain), so a
    loop built on it has no seam. tilt < 0 makes it darker (dB per octave)."""
    n = samples(duration)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    shape = ((freqs >= low) & (freqs <= high)).astype(float)
    with np.errstate(divide="ignore"):
        shape *= np.where(freqs > 0, (freqs / 1000.0) ** (tilt / 6.02), 0)
    out = np.fft.irfft(spectrum * shape, n)
    return out / (np.std(out) + 1e-12)


def looped_band(duration, center, width):
    """Periodic noise around one frequency (a whistle of wind), gaussian shaped."""
    n = samples(duration)
    spectrum = np.fft.rfft(rng.standard_normal(n))
    freqs = np.fft.rfftfreq(n, 1 / RATE)
    out = np.fft.irfft(spectrum * np.exp(-0.5 * ((freqs - center) / width) ** 2), n)
    return out / (np.std(out) + 1e-12)


def loop_freq(freq, duration):
    """The nearest frequency that fits a whole number of cycles into `duration`, so a held
    tone in a loop meets itself exactly at the seam (at most 1/duration Hz off)."""
    return max(1, round(freq * duration)) / duration


def lfo(duration, cycles, phase=0.0, low=0.0, high=1.0):
    """A slow sine between low and high that completes whole cycles over `duration`, so it
    loops without a jump."""
    t = times(duration)
    wave = 0.5 + 0.5 * np.sin(2 * np.pi * cycles * t / duration + phase)
    return low + (high - low) * wave


# ---------------------------------------------------------------- reverb


def _impulse(decay, brightness, predelay=0.02, width=1.0):
    n = samples(decay * 1.2 + predelay)
    t = np.arange(n) / RATE
    ir = np.zeros((n, 2))
    start = samples(predelay)
    for ch in range(2):
        tail = rng.standard_normal(n - start) * np.exp(-6.9 * t[: n - start] / decay)
        tail = lowpass(tail, brightness, 1)
        ir[start:, ch] = tail
    if width < 1:
        mid = ir.mean(axis=1, keepdims=True)
        ir = mid + (ir - mid) * width
    return ir / np.sqrt(np.sum(ir**2) / 2)


def reverb(sig, decay=2.0, mix=0.3, brightness=6000, wrap=False):
    """A big room. wrap: circular, so the tail of a loop's end rings into its start."""
    if sig.ndim == 1:
        sig = stereo(sig)
    ir = _impulse(decay, brightness)
    wet = np.zeros_like(sig) if wrap else np.zeros((len(sig) + len(ir) - 1, 2))
    for ch in range(2):
        if wrap:
            n = len(sig)
            size = n if len(ir) <= n else len(ir)
            spec = np.fft.rfft(sig[:, ch], size) * np.fft.rfft(ir[:, ch], size)
            full = np.fft.irfft(spec, size)
            wet[:, ch] = full[:n] if size == n else _fold(full, n)
        else:
            wet[:, ch] = signal.fftconvolve(sig[:, ch], ir[:, ch])
    dry = sig if wrap else np.vstack([sig, np.zeros((len(ir) - 1, 2))])
    return dry * (1 - mix) + wet * mix * 0.35


def _fold(x, n):
    out = np.zeros(n)
    for i in range(0, len(x), n):
        chunk = x[i : i + n]
        out[: len(chunk)] += chunk
    return out


def trim_tail(sig, threshold=1e-4):
    loud = np.where(np.max(np.abs(sig), axis=1) > threshold)[0]
    return sig[: (loud[-1] + 1 if len(loud) else 1)]


# ---------------------------------------------------------------- instruments


def additive(freq, duration, partials, wobble=0.0, wobble_rate=0.7, vibrato=0.0, vib_rate=5.0):
    """partials: (ratio, amplitude, decay per second). wobble: slow pitch drift like a worn
    tape (creepy); vibrato: fast pitch wiggle like a voice."""
    t = times(duration)
    bend = 1 + wobble * np.sin(2 * np.pi * wobble_rate * t + rng.uniform(0, 6.28))
    bend = bend + vibrato * np.sin(2 * np.pi * vib_rate * t) * np.clip(t / 0.3, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * bend) / RATE
    out = np.zeros_like(t)
    for ratio, amp, decay in partials:
        if freq * ratio < RATE * 0.45:
            out += amp * np.sin(phase * ratio) * np.exp(-decay * t)
    return out


def music_box(freq, duration=2.5, wobble=0.0035):
    """A music-box tine: bright, bell-like, a little out of tune (the haunted kind)."""
    tone = additive(
        freq,
        duration,
        [(1, 1.0, 2.2), (2.0, 0.18, 5), (3.0, 0.05, 8), (5.4, 0.12, 14), (8.9, 0.05, 22)],
        wobble=wobble,
    )
    click = highpass(noise(0.004), 3000) * 0.15
    tone[: len(click)] += click
    return tone * envelope(len(tone), 0.001, release=0.05)


def celesta(freq, duration=2.0):
    tone = additive(freq, duration, [(1, 1.0, 2.8), (2.0, 0.35, 5), (4.0, 0.08, 10), (6.1, 0.04, 16)])
    return tone * envelope(len(tone), 0.002, release=0.08)


def bell(freq, duration=4.0, brightness=1.0):
    """A church-ish bell (Risset's inharmonic partials)."""
    parts = [
        (0.56, 1.0, 0.9),
        (0.92, 0.67, 1.1),
        (1.19, 1.0, 1.6),
        (1.71, 1.8 * brightness, 2.2),
        (2.0, 2.67 * brightness, 2.8),
        (2.74, 1.67 * brightness, 3.4),
        (3.0, 1.46 * brightness, 4.2),
        (3.76, 1.33 * brightness, 5.0),
        (4.07, 1.33 * brightness, 6.0),
    ]
    tone = additive(freq / 0.56, duration, parts)  # freq is the hum note
    return tone / 6 * envelope(len(tone), 0.002, release=0.2)


def pluck(freq, duration=1.5, brightness=0.5, damping=0.996):
    """Karplus-Strong plucked string (harp, pizzicato)."""
    n = samples(duration)
    period = max(2, int(round(RATE / freq)))
    burst = rng.uniform(-1, 1, period)
    burst = lowpass(burst, 1000 + 9000 * brightness, 1)
    x = np.zeros(n)
    x[:period] = burst
    a = np.zeros(period + 2)
    a[0] = 1
    a[period] = -damping * 0.5
    a[period + 1] = -damping * 0.5
    out = signal.lfilter([1.0], a, x)
    return out * envelope(n, 0.001, release=0.05) * 0.8


def soft_piano(freq, duration=3.0):
    """Not a real piano: a felt-soft pluck under a warm sine, good for quiet bass notes."""
    body = additive(freq, duration, [(1, 1.0, 0.9), (2, 0.4, 1.6), (3, 0.15, 2.6), (4, 0.06, 3.5)])
    string = pluck(freq, duration, brightness=0.25, damping=0.998) * 0.5
    return (body * 0.6 + string) * envelope(samples(duration), 0.006, release=0.3)


def organ(freq, duration, stops=(1.0, 0.7, 0.45, 0.35, 0.2, 0.15), sub=0.5, attack=0.03):
    """Pipe organ: drawbar-style harmonics plus a sub octave, steady while held."""
    ratios = (1, 2, 3, 4, 6, 8)
    parts = [(r, a, 0.0) for r, a in zip(ratios, stops)]
    parts.append((0.5, sub, 0.0))
    t = times(duration)
    a = additive(freq, duration, parts)
    b = additive(freq * 1.0025, duration, parts)  # second rank, a hair sharp: chorus
    tone = (a + b * 0.6) * (1 + 0.04 * np.sin(2 * np.pi * 5.5 * t))
    chiff = bandpass(noise(0.06), freq * 2, freq * 6) * np.linspace(0.3, 0, samples(0.06))
    tone[: len(chiff)] += chiff
    return tone * envelope(len(tone), attack, release=0.12) / 3


def saw_stack(freq, duration, voices=5, detune=0.008, cutoff=1800):
    """Detuned band-limited saws: strings and pads."""
    t = times(duration)
    out = np.zeros_like(t)
    harmonics = max(1, int(min(cutoff * 2, RATE * 0.45) / freq))
    for v in range(voices):
        f = freq * (1 + detune * (v - (voices - 1) / 2) / max(1, voices - 1) * 2)
        phase = rng.uniform(0, 2 * np.pi)
        for k in range(1, min(harmonics, 40) + 1):
            out += np.sin(2 * np.pi * f * k * t + phase * k) / k
    return lowpass(out / voices, cutoff)


def pad(freq, duration, attack=1.0, release=1.5, cutoff=1400):
    sig = saw_stack(freq, duration, cutoff=cutoff) * 0.4
    return sig * envelope(len(sig), attack, release=release)


def reed(freq, duration, vibrato=0.004):
    """A bassoon-ish reed: hollow, nasal, with a little vibrato."""
    parts = [(1, 1.0, 0), (2, 0.8, 0), (3, 0.55, 0), (4, 0.35, 0), (5, 0.25, 0), (6, 0.12, 0), (7, 0.08, 0)]
    tone = additive(freq, duration, parts, vibrato=vibrato)
    tone = lowpass(tone, 1100)
    return tone * envelope(len(tone), 0.025, release=0.06) / 2.5


FORMANTS = {
    "ah": [(730, 1.0, 90), (1090, 0.5, 110), (2440, 0.25, 140)],
    "oo": [(300, 1.0, 70), (870, 0.4, 90), (2240, 0.1, 120)],
    "oh": [(570, 1.0, 80), (840, 0.6, 100), (2410, 0.15, 130)],
}


def voice(freq, duration, vowel="ah", vibrato=0.006):
    """A sung vowel: harmonics shaped by the vowel's formants."""
    t = times(duration)
    bend = 1 + vibrato * np.sin(2 * np.pi * 5.2 * t + rng.uniform(0, 6)) * np.clip(t / 0.4, 0, 1)
    phase = 2 * np.pi * np.cumsum(freq * bend) / RATE
    out = np.zeros_like(t)
    for k in range(1, 60):
        fk = freq * k
        if fk > 5000:
            break
        amp = sum(a * np.exp(-0.5 * ((fk - f) / w) ** 2) for f, a, w in FORMANTS[vowel]) + 0.02 / k
        out += amp * np.sin(phase * k)
    return out * envelope(len(out), 0.25, release=0.6)


def choir(freqs, duration, vowel="ah", voices=3):
    out = np.zeros(samples(duration))
    for f in freqs:
        for v in range(voices):
            out += voice(f * (1 + (v - 1) * 0.004), duration, vowel)
    return out / (len(freqs) * voices) * 2.5


def timpani(freq, duration=2.0, hit=0.5):
    t = times(duration)
    f = freq * (1 + 0.04 * np.exp(-t * 20))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    body = (np.sin(phase) + 0.5 * np.sin(phase * 1.5) * np.exp(-t * 4) + 0.3 * np.sin(phase * 1.99)) * np.exp(-t * 2.2)
    thump = lowpass(noise(duration), 500) * np.exp(-t * 30) * hit
    return (body + thump) * 0.6


def boom(duration=3.0, freq=45):
    """A deep cinematic hit."""
    t = times(duration)
    f = freq * (1 + 1.5 * np.exp(-t * 12))
    tone = np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 1.6)
    thump = lowpass(noise(duration), 200) * np.exp(-t * 8) * 0.6
    return (tone + thump) * envelope(len(t), 0.002, release=0.4)


def heartbeat(gain=1.0):
    """'Lub-dub': two soft low thumps."""
    def thump(f, d):
        t = times(d)
        return np.sin(2 * np.pi * f * t * (1 - 0.3 * t / d)) * np.exp(-t * 18) * envelope(len(t), 0.004, release=0.02)

    out = np.zeros(samples(0.6))
    out[: samples(0.25)] += thump(58, 0.25)
    out[samples(0.22) : samples(0.22) + samples(0.25)] += thump(50, 0.25) * 0.7
    return lowpass(out, 160) * gain


def clink(freq=None, duration=0.5):
    """A coin clinking: a handful of bright inharmonic partials that die fast."""
    base = freq or rng.uniform(2200, 3600)
    ratios = [1, 1.47, 2.09, 2.56, 3.1]
    parts = [(r * rng.uniform(0.98, 1.02), rng.uniform(0.4, 1.0), rng.uniform(5, 12) * r) for r in ratios]
    tone = additive(base, duration, parts)
    return tone * envelope(len(tone), 0.0005, release=0.05) / 3


def pop(start=250, end=1100, duration=0.07):
    """A bubble popping: a quick upward chirp."""
    t = times(duration)
    f = start * (end / start) ** (t / duration)
    return np.sin(2 * np.pi * np.cumsum(f) / RATE) * np.exp(-t * 40) * envelope(len(t), 0.001, release=0.01)


def whoosh(duration=1.5, low=300, high=4000, rise=True):
    """Air moving past: filtered noise that swells and slides."""
    n = samples(duration)
    t = np.linspace(0, 1, n)
    bands = np.geomspace(low, high, 8)
    out = np.zeros(n)
    for i, center in enumerate(bands):
        band = bandpass(noise(duration), center * 0.8, center * 1.25)
        pos = i / (len(bands) - 1)
        peak = t if rise else 1 - t
        out += band * np.exp(-((peak - pos) ** 2) / 0.04)
    swell = np.sin(np.pi * t) ** 2
    return out * swell / 3


def crack(duration=0.8):
    """Ice or a branch snapping: a sharp crackle burst."""
    n = samples(duration)
    out = np.zeros(n)
    for _ in range(14):
        at = int(abs(rng.normal(0, 0.05)) * RATE)
        size = samples(rng.uniform(0.002, 0.012))
        if at + size < n:
            out[at : at + size] += highpass(noise(seconds(size)), 1500) * rng.uniform(0.4, 1)
    tail = highpass(noise(duration), 2500) * np.exp(-times(duration) * 14) * 0.25
    return out + tail


def thunder(duration=4.0, near=True):
    t = times(duration)
    rumble = lowpass(noise(duration), 180, 2)
    rumble *= np.exp(-t * 0.9) * (0.6 + 0.4 * lowpass(np.abs(noise(duration)), 6, 1) * 6)
    out = rumble * 3
    if near:
        snap = highpass(noise(0.15), 800) * np.exp(-times(0.15) * 25)
        out[: len(snap)] += snap * 1.2
        out += lowpass(noise(duration), 900) * np.exp(-t * 6) * 0.8
    return out * envelope(len(t), 0.01, release=0.5)


def hum(freq, duration, buzz=0.6):
    """Electrical mains hum with a buzzy edge, like a failing streetlight."""
    t = times(duration)
    parts = [(k, 1 / k ** (1.2 - buzz * 0.6), 0) for k in range(1, 30)]
    tone = additive(freq, duration, parts)
    return bandpass(tone, 60, 4000) * 0.2 * (1 + 0.1 * np.sin(2 * np.pi * 7 * t))


def howl(duration=3.0, base=420):
    """A distant wolf: a voice gliding up, holding, falling away."""
    t = times(duration)
    shape = np.interp(t / duration, [0, 0.25, 0.7, 1], [0.75, 1.25, 1.15, 0.7])
    f = base * shape * (1 + 0.012 * np.sin(2 * np.pi * 5.5 * t))
    phase = 2 * np.pi * np.cumsum(f) / RATE
    tone = np.sin(phase) + 0.35 * np.sin(phase * 2) + 0.1 * np.sin(phase * 3)
    breath = bandpass(noise(duration), 500, 2000) * 0.05
    return (tone + breath) * envelope(len(t), 0.4, release=1.0) * 0.5


def whisper(duration=1.2):
    """Breathy hiss shaped like a whispered syllable."""
    t = times(duration)
    out = np.zeros_like(t)
    for f, w in [(rng.uniform(800, 1400), 300), (rng.uniform(2200, 3200), 500), (6000, 1500)]:
        out += bandpass(noise(duration), f - w, f + w)
    shape = np.interp(t, [0, duration * 0.2, duration * 0.5, duration], [0, 1, 0.6, 0]) ** 1.5
    syll = 1 + 0.6 * np.sin(2 * np.pi * rng.uniform(3, 6) * t)
    return out * shape * syll * 0.3
