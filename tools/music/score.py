"""A small score format for writing pieces as notes, and the renderer that turns them into stereo audio.

Melodies are written as scale degrees in the piece's mode, one string per bar:
    "1:1.5 2:0.5 4:2"   degree 1 for one and a half beats, degree 2 for half a beat, degree 4 for two
    5'  an octave up, 5, an octave down, 4+ raised a half step, 2- lowered, r:2 a rest of two beats
Chords are scale-degree roots, voiced in thirds of the mode.
"""
import os
import subprocess
import wave

import numpy as np
from scipy.signal import fftconvolve

from instruments import SR, PITCHED, UNPITCHED, mtof, _filter

MODES = {
    "ionian": [0, 2, 4, 5, 7, 9, 11],
    "dorian": [0, 2, 3, 5, 7, 9, 10],
    "phrygian": [0, 1, 3, 5, 7, 8, 10],
    "lydian": [0, 2, 4, 6, 7, 9, 11],
    "mixolydian": [0, 2, 4, 5, 7, 9, 10],
    "aeolian": [0, 2, 3, 5, 7, 8, 10],
    "locrian": [0, 1, 3, 5, 6, 8, 10],
}
NOTES = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def midi(name, octave):
    """midi("D", 3) -> 50. A trailing b or # on the name flattens or sharpens it."""
    acc = name.count("#") - name.count("b")
    return 12 * (octave + 1) + NOTES[name[0]] + acc


class Song:
    def __init__(self, name, title, bpm, meter, tonic, mode, reverb=(2.4, 0.55), humanize=0.008, seed=1):
        self.name, self.title = name, title
        self.bpm, self.meter, self.tonic, self.mode = bpm, meter, tonic, mode
        self.reverb, self.humanize = reverb, humanize
        self.rng = np.random.default_rng(seed)
        self.events = []  # (seconds, instrument, midi or None, seconds held, velocity, pan, reverb send, shape)
        self.top = []     # events heard through a cut
        self.cuts = []    # (from beat, to beat): everything but the top events falls silent

    # time and pitch
    def sec(self, beat):
        return beat * 60.0 / self.bpm

    def at(self, bar, beat=0.0):
        return bar * self.meter + beat

    def pitch(self, degree, acc=0, mode=None):
        octave, step = divmod(degree, 7)
        return self.tonic + MODES[mode or self.mode][step] + 12 * octave + acc

    # writing
    def note(self, inst, beat, beats, pitch, vel=0.6, pan=0.0, send=0.35, shape=None):
        jitter = self.rng.normal(0, self.humanize) if self.humanize else 0.0
        v = float(np.clip(vel + self.rng.normal(0, 0.03), 0.04, 1.0))
        self.events.append((max(0.0, self.sec(beat) + jitter), inst, pitch, self.sec(beats), v, pan, send, shape))

    def hit(self, inst, beat, vel=0.6, pan=0.0, send=0.3, beats=1.0, top=False):
        jitter = self.rng.normal(0, self.humanize) if self.humanize else 0.0
        (self.top if top else self.events).append((max(0.0, self.sec(beat) + jitter), inst, None, self.sec(beats), vel, pan, send, None))

    @staticmethod
    def parse(bar):
        out, pos = [], 0.0
        for token in bar.split():
            degree, beats = token.split(":")
            beats = float(beats)
            if degree == "r":
                pos += beats
                continue
            octave = acc = 0
            while degree[-1] in "',+-":
                c = degree[-1]
                octave += {"'": 1, ",": -1}.get(c, 0)
                acc += {"+": 1, "-": -1}.get(c, 0)
                degree = degree[:-1]
            out.append((pos, beats, int(degree) - 1 + 7 * octave, acc))
            pos += beats
        return out, pos

    def mel(self, inst, bar0, bars, vel=0.6, octave=0, pan=0.0, send=0.35, legato=0.96, shift=0, shape=None, mode=None):
        """Plays one string per bar. shift moves the line by scale steps (-4 is a fifth below)."""
        for i, bar in enumerate(bars):
            notes, length = self.parse(bar)
            if abs(length - self.meter) > 1e-6:
                raise ValueError(f"{self.name}: bar '{bar}' has {length} beats, the meter is {self.meter}")
            for off, beats, degree, acc in notes:
                accent = 0.06 if off == 0 else 0.0
                self.note(inst, self.at(bar0 + i, off), beats * legato, self.pitch(degree + shift, acc, mode) + 12 * octave,
                          vel + accent, pan, send, shape)
        return bar0 + len(bars)

    def chords(self, inst, bar0, roots, vel=0.4, octave=-1, pan=0.0, send=0.45, voicing=(0, 2, 4), bars_each=1,
               spread=0.3, shape=None, mode=None):
        """One chord per bar (or per bars_each bars), built from the mode on each root degree."""
        for i, root in enumerate(roots):
            if root is None:
                continue
            for k, step in enumerate(voicing):
                p = (k - (len(voicing) - 1) / 2) * spread / max(1, len(voicing) - 1) * 2
                self.note(inst, self.at(bar0 + i * bars_each), self.meter * bars_each * 0.98,
                          self.pitch(root + step, 0, mode) + 12 * octave, vel, pan + p, send, shape)
        return bar0 + len(roots) * bars_each

    def broken(self, inst, bar0, roots, pattern, step, vel=0.45, octave=-1, pan=0.0, send=0.35, ring=2.5):
        """A broken chord per bar: pattern lists chord steps (0 root, 2 third, 4 fifth, 7 octave, '-' rest)."""
        for i, root in enumerate(roots):
            for s in range(int(round(self.meter / step))):
                tok = pattern[s % len(pattern)]
                if tok == "-":
                    continue
                self.note(inst, self.at(bar0 + i, s * step), step * ring, self.pitch(root + int(tok, 16)) + 12 * octave,
                          vel + (0.06 if s == 0 else 0.0), pan, send)
        return bar0 + len(roots)

    def scatter(self, inst, bar0, nbars, per_bar, vel=(0.3, 0.6), pan=(-0.8, 0.8), send=0.5, beats=2.0):
        """Unpitched events at random places: whispers, scrapes, drops."""
        for b in range(bar0, bar0 + nbars):
            lo, hi = per_bar
            for _ in range(int(self.rng.integers(lo, hi + 1))):
                self.hit(inst, self.at(b, self.rng.uniform(0, self.meter)), self.rng.uniform(*vel),
                         self.rng.uniform(*pan), send, beats)

    # rendering
    def render(self):
        end = max(e[0] + e[3] for e in self.events + self.top) + 9.0
        L, R = self._mix(self.events, end)
        for start, stop in self.cuts:
            a, b = int(self.sec(start) * SR), int(self.sec(stop) * SR)
            ramp = int(0.03 * SR)
            gain = np.ones(len(L))
            gain[a:b] = 0.0
            gain[max(0, a - ramp):a] = np.linspace(1, 0, a - max(0, a - ramp))
            gain[b:b + ramp] = np.linspace(0, 1, len(gain[b:b + ramp]))
            L, R = L * gain, R * gain
        if self.top:
            tl, tr = self._mix(self.top, end)
            L, R = L + tl, R + tr
        return _master(L, R)

    def _mix(self, events, end):
        L = np.zeros(int(end * SR))
        R = np.zeros_like(L)
        wet = np.zeros_like(L)
        cache = {}
        for t0, inst, pitch, held, vel, pan, send, shape in sorted(events, key=lambda e: e[0]):
            key = (inst, pitch, round(held, 2), round(vel, 2))
            if key not in cache:
                if pitch is None:
                    cache[key] = UNPITCHED[inst](0.0, held, vel)
                else:
                    cache[key] = PITCHED[inst](mtof(pitch), held, vel)
            x = cache[key]
            if shape:
                x = x * _shape(shape, len(x), held)
            i = int(t0 * SR)
            x = x[: len(L) - i]
            angle = (np.clip(pan, -1, 1) + 1) * np.pi / 4
            L[i:i + len(x)] += x * np.cos(angle)
            R[i:i + len(x)] += x * np.sin(angle)
            wet[i:i + len(x)] += x * send
        seconds, darkness = self.reverb
        return _reverb(L, R, wet, seconds, darkness)

    def write(self, folder):
        L, R = self.render()
        os.makedirs(folder, exist_ok=True)
        wav = os.path.join(folder, self.name + ".wav")
        data = (np.clip(np.stack([L, R], 1), -1, 1) * 32767).astype(np.int16)
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes(data.tobytes())
        ogg = os.path.join(folder, self.name + ".ogg")
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "2", ogg],
                       check=True)
        os.remove(wav)
        return L, R


def _shape(kind, n, held):
    u = np.clip(np.arange(n) / SR / max(held, 1e-3), 0, 1)
    if kind == "swell":
        return 0.15 + 0.85 * u ** 1.6
    if kind == "dim":
        return 1.0 - 0.85 * u ** 0.8
    if kind == "arc":
        return 0.2 + 0.8 * np.sin(np.pi * u) ** 1.2
    return np.ones(n)


def _reverb(L, R, wet, seconds, darkness):
    """A church-like hall: an impulse of decaying noise, darker as it fades, with a short pre-delay."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(7)
    tails = []
    for side in range(2):
        noise = rng.normal(0, 1, n) * np.exp(-6.9 * t / seconds)
        noise = _filter(noise, "low", 9000 - 6500 * darkness)
        noise[: int(0.025 * SR)] = 0.0
        tails.append(noise / np.sqrt(np.sum(noise ** 2)))
    return L + fftconvolve(wet, tails[0])[: len(L)] * 0.9, R + fftconvolve(wet, tails[1])[: len(R)] * 0.9


def _master(L, R, target_rms=0.14, ceiling=0.88):
    """Brings the piece to a steady level with a soft limiter, trims the silence, fades the ends."""
    peak = max(np.max(np.abs(L)), np.max(np.abs(R)), 1e-9)
    L, R = L / peak, R / peak
    mono = (L + R) / 2
    win = SR // 2
    frames = np.array([np.sqrt(np.mean(mono[i:i + win] ** 2)) for i in range(0, len(mono) - win, win)])
    body = np.percentile(frames[frames > 0.005], 75) if np.any(frames > 0.005) else 0.1
    gain = float(np.clip(target_rms / body, 0.5, 8.0))
    L, R = np.tanh(L * gain * 1.15) / 1.15, np.tanh(R * gain * 1.15) / 1.15
    peak = max(np.max(np.abs(L)), np.max(np.abs(R)))
    if peak > ceiling:
        L, R = L * ceiling / peak, R * ceiling / peak
    loud = np.where(np.abs((L + R) / 2) > 0.0015)[0]
    cut = min(len(L), (loud[-1] if len(loud) else len(L)) + int(0.4 * SR))
    L, R = L[:cut].copy(), R[:cut].copy()
    f = int(0.02 * SR)
    for ch in (L, R):
        ch[:f] *= np.linspace(0, 1, f)
        ch[-int(1.0 * SR):] *= np.linspace(1, 0, int(1.0 * SR)) ** 2
    return L, R


def measure(L, R):
    """Loudness every ten seconds (dB RMS), the peak, and the length: how a piece is checked without ears."""
    mono = (L + R) / 2
    step = 10 * SR
    curve = [20 * np.log10(np.sqrt(np.mean(mono[i:i + step] ** 2)) + 1e-9) for i in range(0, len(mono), step)]
    peak = 20 * np.log10(max(np.max(np.abs(L)), np.max(np.abs(R))))
    whole = 20 * np.log10(np.sqrt(np.mean(mono ** 2)) + 1e-9)
    return {"seconds": len(L) / SR, "rms_db": whole, "peak_db": peak, "curve": [round(c, 1) for c in curve]}
