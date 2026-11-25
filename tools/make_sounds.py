#!/usr/bin/env python3
"""Writes BluJem's game sounds to assets/sounds/: soft bell tones, every one
fading to silence so none ends with a click. Run from the repo root:

    python3 tools/make_sounds.py
"""
import math
import random
import struct
import wave

RATE = 44100


def note(name):
    """'C5' -> its frequency in Hz."""
    steps = {'C': -9, 'D': -7, 'E': -5, 'F': -4, 'G': -2, 'A': 0, 'B': 2}[name[0]]
    return 440 * 2 ** ((steps + 12 * (int(name[-1]) - 4)) / 12)


def bell(freq, seconds, decay=6.0, attack=0.004):
    """A soft bell: the tone and two quiet overtones, a quick rise, then an
    exponential fall that reaches silence by the end."""
    n = int(RATE * seconds)
    out = []
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t) * (1 - i / n)
        s = (math.sin(2 * math.pi * freq * t)
             + 0.35 * math.sin(2 * math.pi * freq * 2 * t)
             + 0.12 * math.sin(2 * math.pi * freq * 3.01 * t))
        out.append(env * s / 1.47)
    return out


def mix(length, *parts):
    """Lays (start seconds, samples, gain) parts over silence."""
    out = [0.0] * int(RATE * length)
    for start, samples, gain in parts:
        at = int(RATE * start)
        for i, s in enumerate(samples):
            if at + i < len(out):
                out[at + i] += s * gain
    return out


def swish(seconds):
    """Shuffling tiles: filtered noise that swells and dies away."""
    random.seed(7)
    n = int(RATE * seconds)
    out, low = [], 0.0
    for i in range(n):
        x = i / n
        low += 0.18 * (random.uniform(-1, 1) - low)
        out.append(low * math.sin(math.pi * x) ** 2 * 2.2)
    return out


def tick():
    """A key press: a short, woody tick."""
    n = int(RATE * 0.05)
    return [math.exp(-90 * (i / RATE)) * math.sin(2 * math.pi * 1800 * i / RATE) * (1 - i / n) for i in range(n)]


def write(name, samples, peak=0.7):
    """Scales to [peak] of full volume, so nothing clips or shouts."""
    top = max(abs(s) for s in samples) or 1
    with wave.open(f'assets/sounds/{name}.wav', 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(s / top * peak * 32767)) for s in samples))


write('sfx_key', tick(), peak=0.45)
write('sfx_solved', mix(0.7, (0, bell(note('E5'), 0.45), 0.8), (0.09, bell(note('B5'), 0.6), 1.0)), peak=0.6)
write('sfx_complete', mix(
    2.0,
    (0.00, bell(note('C5'), 0.9, decay=4), 0.8),
    (0.12, bell(note('E5'), 0.9, decay=4), 0.8),
    (0.24, bell(note('G5'), 0.9, decay=4), 0.8),
    (0.38, bell(note('C6'), 1.6, decay=2.2), 1.0),
    (0.38, bell(note('G5'), 1.6, decay=2.2), 0.5),
    (0.38, bell(note('E5'), 1.6, decay=2.2), 0.5),
), peak=0.7)
write('sfx_start', mix(0.55, (0, bell(note('G4'), 0.35), 0.8), (0.1, bell(note('D5'), 0.45), 1.0)), peak=0.55)
write('sfx_shuffle', swish(0.32), peak=0.4)
write('sfx_timeout', mix(0.8, (0, bell(note('E4'), 0.4, decay=5), 0.9), (0.18, bell(note('C4'), 0.6, decay=4), 1.0)), peak=0.55)
write('sfx_hint', mix(
    0.6,
    (0.00, bell(note('A5'), 0.30, decay=9), 0.55),
    (0.07, bell(note('C6'), 0.30, decay=9), 0.6),
    (0.14, bell(note('E6'), 0.45, decay=7), 0.75),
    (0.14, bell(note('A6'), 0.40, decay=9), 0.2),
), peak=0.42)
