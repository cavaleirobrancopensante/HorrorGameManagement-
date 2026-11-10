"""Daily Bread's instruments, synthesised from scratch with numpy.

Three worlds meet in the game, and each has its own instruments:
  The Church      pipe organ, a male schola chanting, tolling and pealing bells, a harmonium
  The State       cold synthesiser pads, a sub drone, the Civic chime, radio static
  The Adversary   whispers, a heartbeat, metal scrapes, booms, reversed swells, low brass, dark strings
And the home between them: a worn upright piano, slightly out of tune, and rain on a tin roof.

Every instrument is a function (freq, seconds, velocity) -> mono samples at SR. Unpitched ones ignore
freq. All randomness is seeded from the note, so a piece renders the same every time.
"""
import zlib

import numpy as np
from scipy.signal import butter, sosfilt

SR = 32000


def _t(n):
    return np.arange(n) / SR


def mtof(m):
    return 440.0 * 2 ** ((m - 69) / 12)


def _rng(*key):
    """A random source fixed by the note, the same on every run."""
    text = repr(tuple(round(k, 4) if isinstance(k, float) else k for k in key))
    return np.random.default_rng(zlib.crc32(text.encode()))


def _env(n, n_hold, attack, release):
    """Linear attack, held level, a smooth release after n_hold."""
    e = np.ones(n)
    na = min(n, max(1, int(attack * SR)))
    e[:na] = np.linspace(0.0, 1.0, na)
    if n > n_hold:
        e[n_hold:] *= np.linspace(1.0, 0.0, n - n_hold) ** 2
    return e


def _sos(kind, f, order=2):
    if kind == "band":
        lo, hi = f
        return butter(order, [max(lo, 20) / (SR / 2), min(hi, SR / 2 - 100) / (SR / 2)], btype="band", output="sos")
    return butter(order, min(f, SR / 2 - 100) / (SR / 2), btype=kind, output="sos")


def _filter(x, kind, f, order=2):
    return sosfilt(_sos(kind, f, order), x)


def _vib_phase(freq, n, rate=0.0, depth=0.0, delay=0.3, drift=0.0, seed=0):
    """Phase in cycles of a tone with delayed vibrato and a slow random drift."""
    t = _t(n)
    f = np.full(n, freq)
    if depth:
        ramp = np.clip((t - delay) / 0.4, 0.0, 1.0)
        f = f * (1.0 + depth * ramp * np.sin(2 * np.pi * rate * t + seed))
    if drift:
        walk = np.cumsum(_rng("drift", freq, seed).normal(0, 1, n // 400 + 2))
        walk = np.interp(np.arange(n), np.arange(len(walk)) * 400, walk)
        f = f * (1.0 + drift * walk / (np.max(np.abs(walk)) + 1e-9))
    return np.cumsum(f) / SR


def _saw_partials(freq, top, falloff):
    ks = np.arange(1, int(top / freq) + 1)
    return ks, (1.0 / ks) * np.exp(-ks * freq / falloff)


# ------------------------------------------------------------------ the Church

def organ(freq, dur, vel=0.7):
    """Pipe organ: flue drawbars (8', 4', 2 2/3', 2', 1 3/5' and a 16' under), slightly chorused."""
    n_hold = int(dur * SR)
    n = n_hold + int(0.35 * SR)
    t = _t(n)
    out = np.zeros(n)
    stops = [(0.5, 0.16), (1, 1.0), (2, 0.65), (3, 0.34), (4, 0.32), (5, 0.1), (6, 0.16), (8, 0.13),
             (10, 0.07), (12, 0.06), (16, 0.035)]
    for det in (-0.0011, 0.0013):
        ph = 2 * np.pi * freq * (1 + det) * t
        for k, a in stops:
            if freq * k < 9000:
                out += a * np.sin(k * ph)
    chiff = _filter(_rng("chiff", freq).normal(0, 1, n), "band", (freq * 2, freq * 6)) * np.exp(-t / 0.03) * 0.25
    trem = 1.0 + 0.035 * np.sin(2 * np.pi * 5.4 * t)
    return (out * trem + chiff) * _env(n, n_hold, 0.06, 0.35) * vel * 0.11


FORMANTS = {
    "a": [(730, 110, 1.0), (1090, 130, 0.5), (2440, 220, 0.18)],
    "o": [(470, 90, 1.0), (840, 110, 0.45), (2410, 220, 0.14)],
    "u": [(330, 70, 1.0), (750, 110, 0.18), (2380, 220, 0.05)],
    "e": [(420, 80, 1.0), (1850, 130, 0.32), (2500, 220, 0.2)],
}


def _formant_gain(f, vowel):
    """Vowel formants plus the singer's formant near 2.9 kHz that lets trained voices carry."""
    vowel_part = sum(a * np.exp(-((f - c) / bw) ** 2) for c, bw, a in FORMANTS[vowel])
    return vowel_part + 0.22 * np.exp(-((f - 2900) / 350) ** 2) + 0.015


def chant(freq, dur, vel=0.7, vowel="o", voices=4):
    """A small schola of men chanting: harmonic voices shaped by vowel formants, each a little apart."""
    n_hold = int(dur * SR)
    n = n_hold + int(0.45 * SR)
    out = np.zeros(n)
    rng = _rng("chant", freq, dur, vowel)
    for v in range(voices):
        det = rng.uniform(-0.0045, 0.0045)
        ph = 2 * np.pi * _vib_phase(freq * (1 + det), n, 4.6 + 0.37 * v, 0.0035, 0.35, 0.0015, v)
        for k in range(1, int(4200 / freq) + 1):
            out += (_formant_gain(k * freq, vowel) / k ** 0.35) * np.sin(k * ph + rng.uniform(0, 6.28))
    breath = _filter(rng.normal(0, 1, n), "band", (FORMANTS[vowel][0][0] * 0.8, 3200)) * 0.07
    return (out / voices + breath) * _env(n, n_hold, 0.16, 0.45) * vel * 0.42


def bell(freq, dur, vel=0.7, ring=4.5):
    """A church bell: the hum, the prime, the minor third, the fifth and the nominal, each dying at its own rate."""
    n = int((max(dur, 0.2) + ring * 1.3) * SR)
    t = _t(n)
    partials = [(0.5, 0.28, 1.4), (1.0, 1.0, 1.0), (1.183, 0.6, 0.75), (1.506, 0.38, 0.6), (2.0, 0.45, 0.5),
                (2.51, 0.25, 0.35), (3.01, 0.16, 0.25), (4.07, 0.1, 0.15), (5.2, 0.06, 0.1)]
    out = np.zeros(n)
    for r, a, d in partials:
        if freq * r < 11000:
            beat = 1.0 + 0.04 * np.sin(2 * np.pi * (0.7 + r * 0.3) * t)
            out += a * beat * np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (ring * d))
    strike = _filter(_rng("strike", freq).normal(0, 1, n), "high", 1800) * np.exp(-t / 0.008) * 0.4
    return (out + strike) * vel * 0.16


def harmonium(freq, dur, vel=0.7):
    """A reed organ worked by bellows: reedy, warm, breathing."""
    n_hold = int(dur * SR)
    n = n_hold + int(0.25 * SR)
    t = _t(n)
    out = np.zeros(n)
    for det in (0.0, 0.0024):
        ph = 2 * np.pi * freq * (1 + det) * t
        ks, amps = _saw_partials(freq, 4500, 1600)
        for k, a in zip(ks, amps):
            out += a * (1.3 if k % 2 else 0.8) * np.sin(k * ph)
    bellows = 1.0 + 0.06 * np.sin(2 * np.pi * 0.9 * t + freq)
    return out * bellows * _env(n, n_hold, 0.12, 0.25) * vel * 0.09


# ------------------------------------------------------------------ home

def piano(freq, dur, vel=0.7, worn=True):
    """An old upright: stiff strings (stretched partials), two strings a hair apart, a felt hammer, and
    every key a little out of tune in its own way."""
    rng = _rng("piano", freq)
    if worn:
        freq *= 2 ** (rng.uniform(-9, 9) / 1200)
    ring = min(dur, 7.0)
    n_hold = int(ring * SR)
    n = n_hold + int(0.3 * SR)
    t = _t(n)
    base_decay = float(np.clip(3.2 * (220 / freq) ** 0.55, 0.5, 9.0))
    out = np.zeros(n)
    stiff = 0.00035
    for k in range(1, 16):
        fk = k * freq * np.sqrt(1 + stiff * k * k)
        if fk > 9500:
            break
        a = (1.0 / k ** 1.05) * np.exp(-k * (1.0 - vel) * 0.28)
        dk = base_decay / (1 + 0.28 * (k - 1))
        env = 0.62 * np.exp(-t / (dk * 0.22)) + 0.38 * np.exp(-t / dk)
        out += a * env * (np.sin(2 * np.pi * fk * t) + 0.8 * np.sin(2 * np.pi * fk * 1.0008 * t + k))
    damp = np.ones(n)
    damp[n_hold:] = np.exp(-_t(n - n_hold) / 0.07)
    hammer = _filter(rng.normal(0, 1, n), "low", 2600) * np.exp(-t / 0.004) * 0.18
    return (out * damp + hammer) * vel * 0.14


def rain(freq, dur, vel=0.5):
    """Rain on a tin roof: a soft hiss and scattered drops."""
    n = int(dur * SR)
    rng = _rng("rain", dur)
    hiss = _filter(_filter(rng.normal(0, 1, n), "low", 3500), "high", 300) * 0.25
    drops = np.zeros(n)
    for _ in range(int(dur * 9)):
        i = rng.integers(0, max(1, n - 3000))
        f = rng.uniform(1800, 5200)
        tt = _t(1500)
        drops[i:i + 1500] += rng.uniform(0.2, 1.0) * np.sin(2 * np.pi * f * tt) * np.exp(-tt / 0.006)
    fade = _env(n, n - int(1.5 * SR), 1.5, 1.5)
    return (hiss + drops * 0.35) * fade * vel * 0.3


# ------------------------------------------------------------------ the State

def pad(freq, dur, vel=0.6):
    """A cold synthesiser pad: three detuned saws through a low filter, breathing slowly."""
    n_hold = int(dur * SR)
    n = n_hold + int(1.8 * SR)
    t = _t(n)
    out = np.zeros(n)
    ks, amps = _saw_partials(freq, 6000, 2100)
    for det in (-0.006, 0.0, 0.0071):
        ph = 2 * np.pi * freq * (1 + det) * t
        for k, a in zip(ks, amps):
            out += a * np.sin(k * ph + det * 400 * k)
    lfo = 1.0 + 0.12 * np.sin(2 * np.pi * 0.13 * t + freq)
    return out * lfo * _env(n, n_hold, 1.4, 1.8) * vel * 0.05


def sub(freq, dur, vel=0.6):
    """A low sine drone you feel more than hear."""
    n_hold = int(dur * SR)
    n = n_hold + int(1.5 * SR)
    t = _t(n)
    x = np.sin(2 * np.pi * freq * t) + 0.18 * np.sin(4 * np.pi * freq * t)
    return x * _env(n, n_hold, 1.2, 1.5) * vel * 0.16


def chime(freq, dur, vel=0.7):
    """The Civic chime: a clean, friendly glass tone. The State's voice."""
    n = int((dur + 1.6) * SR)
    t = _t(n)
    x = np.sin(2 * np.pi * freq * t) + 0.32 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.25)
    return x * np.exp(-t / 0.9) * np.minimum(1.0, t / 0.004) * vel * 0.22


def radio_chime(freq, dur, vel=0.7):
    """The Civic chime as heard from a cheap radio across the street: narrow, crackling."""
    x = chime(freq, dur, vel)
    x = np.tanh(_filter(x, "band", (450, 3200)) * 3.0) * 0.35
    rng = _rng("crackle", freq)
    crackle = (rng.random(len(x)) < 0.0025) * rng.normal(0, 1, len(x)) * 0.25
    return x + _filter(crackle + rng.normal(0, 0.02, len(x)), "band", (600, 4000))


def static(freq, dur, vel=0.5):
    """A burst of radio static, tuning between stations."""
    n = int(dur * SR)
    rng = _rng("static", dur, freq)
    x = _filter(rng.normal(0, 1, n), "band", (700, 5000))
    sweep = np.sin(2 * np.pi * np.cumsum(np.linspace(300, 1400, n)) / SR) * 0.15
    gate = (np.abs(np.sin(2 * np.pi * rng.uniform(3, 7) * _t(n))) > 0.35).astype(float)
    return (x * 0.5 + sweep) * gate * _env(n, n - int(0.05 * SR), 0.02, 0.05) * vel * 0.3


# ------------------------------------------------------------------ the Adversary

def strings(freq, dur, vel=0.6, tremolo=False):
    """A dark string section: an ensemble of bowed saws with vibrato."""
    n_hold = int(dur * SR)
    n = n_hold + int(0.5 * SR)
    t = _t(n)
    out = np.zeros(n)
    ks, amps = _saw_partials(freq, 7000, 3200)
    for v in range(4):
        ph = 2 * np.pi * _vib_phase(freq * (1 + (v - 1.5) * 0.0025), n, 5.1 + v * 0.23, 0.0028, 0.25, 0.0008, v)
        for k, a in zip(ks, amps):
            out += a * np.sin(k * ph + v * k)
    if tremolo:
        out *= 0.65 + 0.35 * np.sin(2 * np.pi * 11.5 * t) ** 2
    return out * _env(n, n_hold, 0.35, 0.5) * vel * 0.05


def tremolo_strings(freq, dur, vel=0.6):
    return strings(freq, dur, vel, True)


def low_brass(freq, dur, vel=0.6):
    """Trombones and tuba, low and slow: dark at the start, opening as the note grows."""
    n_hold = int(dur * SR)
    n = n_hold + int(0.35 * SR)
    t = _t(n)
    grow = np.clip(t / max(dur * 0.7, 0.3), 0.0, 1.0)
    ph = 2 * np.pi * _vib_phase(freq, n, 4.8, 0.0015, 0.5, 0.0006)
    out = np.zeros(n)
    for k in range(1, int(3500 / freq) + 1):
        bright = np.exp(-k / (1.6 + 5.5 * grow * vel))
        out += bright * np.sin(k * ph) / k ** 0.3
    return np.tanh(out * 0.8) * _env(n, n_hold, 0.15, 0.35) * vel * 0.18


def whisper(freq, dur, vel=0.5):
    """A voice that is not there: breath through a mouth, never quite forming words."""
    n = int(dur * SR)
    rng = _rng("whisper", dur, freq)
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    vowels = list(FORMANTS)
    vowel = vowels[rng.integers(0, len(vowels))]
    for c, bw, a in FORMANTS[vowel]:
        out += a * _filter(noise, "band", (c - bw * 1.5, c + bw * 1.5))
    hiss = _filter(noise, "high", 4500) * (rng.random(n // 3200 + 1).repeat(3200)[:n] > 0.7) * 0.5
    flutter = 0.5 + 0.5 * np.abs(np.sin(2 * np.pi * rng.uniform(2.5, 6) * _t(n)))
    return (out + hiss) * flutter * _env(n, n - int(0.4 * SR), 0.3, 0.4) * vel * 0.5


def heartbeat(freq, dur, vel=0.7):
    """Lub-dub."""
    n = int(0.9 * SR)
    t = _t(n)

    def thump(t0, v):
        tt = np.clip(t - t0, 0, None)
        on = (t >= t0).astype(float)
        f = 48 + 30 * np.exp(-tt / 0.03)
        return on * v * np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt / 0.09)

    def knock(t0, v):
        # the body of the beat, in the range a phone speaker can play
        tt = np.clip(t - t0, 0, None)
        on = (t >= t0).astype(float)
        return on * v * (np.sin(2 * np.pi * 160 * tt) * 0.6 + np.sin(2 * np.pi * 240 * tt) * 0.25) * np.exp(-tt / 0.035)

    beat = thump(0.0, 1.0) + thump(0.27, 0.65)
    return (beat * 0.55 + knock(0.0, 1.0) + knock(0.27, 0.6)) * vel * 0.9


def boom(freq, dur, vel=0.8):
    """A deep impact, felt in the chest."""
    n = int(3.0 * SR)
    t = _t(n)
    f = 34 + 60 * np.exp(-t / 0.12)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 1.0)
    noise = _filter(_rng("boom", vel).normal(0, 1, n), "band", (90, 900)) * np.exp(-t / 0.18) * 0.9
    body = (np.sin(2 * np.pi * 130 * t) + 0.5 * np.sin(2 * np.pi * 197 * t)) * np.exp(-t / 0.35) * 0.45
    return (x * 0.6 + noise + body) * vel * 0.8


def scrape(freq, dur, vel=0.5):
    """Metal dragged on metal, somewhere outside."""
    n = int(dur * SR)
    rng = _rng("scrape", dur, freq)
    noise = rng.normal(0, 1, n)
    out = np.zeros(n)
    for f in rng.uniform(700, 3800, 4):
        out += _filter(noise, "band", (f * 0.985, f * 1.015), 2)
    swell = np.sin(np.pi * np.linspace(0, 1, n)) ** 1.5
    jitter = 0.6 + 0.4 * (rng.random(n // 800 + 1).repeat(800)[:n])
    return out * swell * jitter * vel * 0.9


def reverse_swell(freq, dur, vel=0.6):
    """A struck cluster played backwards: it rushes up out of nothing and stops dead."""
    n = int(dur * SR)
    t = _t(n)
    x = np.zeros(n)
    for r in (1.0, 1.0595, 1.4142, 2.0):
        x += np.sin(2 * np.pi * freq * r * t) * np.exp(-t / (dur * 0.35))
    x += _filter(_rng("rev", freq).normal(0, 1, n), "band", (freq * 2, freq * 12)) * np.exp(-t / (dur * 0.2)) * 0.6
    return x[::-1] * vel * 0.25


PITCHED = {
    "organ": organ, "chant": chant, "chant_a": lambda f, d, v: chant(f, d, v, "a"),
    "chant_u": lambda f, d, v: chant(f, d, v, "u"), "chant_e": lambda f, d, v: chant(f, d, v, "e"),
    "bell": bell, "toll": lambda f, d, v: bell(f, d, v, 7.5), "harmonium": harmonium,
    "piano": piano, "pad": pad, "sub": sub, "chime": chime, "radio_chime": radio_chime,
    "strings": strings, "tremolo": tremolo_strings, "low_brass": low_brass, "reverse": reverse_swell,
}
UNPITCHED = {
    "rain": rain, "static": static, "whisper": whisper, "heartbeat": heartbeat, "boom": boom, "scrape": scrape,
}
