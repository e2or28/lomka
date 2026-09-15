#!/usr/bin/env python3
"""Собственные синтезированные эффекты Ломки, без внешних семплов."""
import math
import random
import struct
import wave
from pathlib import Path

RATE = 22050
SOUNDS = {
    'shot': 0.15, 'paper': 0.24, 'hit': 0.13, 'pickup': 0.24,
    'harvest': 0.34, 'down': 0.42, 'revive': 0.50, 'wave': 0.42, 'door': 0.23, 'explosion': 1.2,
}


def synth(name, seconds):
    rng = random.Random(name)
    samples = []
    previous = 0.0
    low = 0.0
    for i in range(round(seconds * RATE)):
        t = i / RATE
        p = t / seconds
        noise = rng.uniform(-1, 1)
        high = noise - previous
        previous = noise
        attack = min(1, t / 0.004)
        release = min(1, (seconds - t) / 0.02)
        if name == 'explosion':
            low += (noise - low) * 0.11
            boom = math.sin(math.tau * (31 * t + 38 * (1 - math.exp(-9 * t)) / 9))
            value = (high * 0.52 * math.exp(-t * 65)
                     + boom * 0.78 * math.exp(-t * 7)
                     + low * 2.6 * math.exp(-t * 3.5))
            for delay, frequency in [(0.13, 970), (0.22, 1510), (0.34, 710), (0.47, 1890)]:
                age = t - delay
                if age >= 0:
                    value += 0.11 * math.sin(math.tau * frequency * age) * math.exp(-age * 32) * min(1, age / 0.002)
        elif name == 'shot':
            value = (0.6 * high * math.exp(-t * 55)
                     + 0.7 * math.sin(math.tau * (130 * t - 220 * t * t)) * math.exp(-t * 25))
        elif name == 'paper':
            value = high * (0.25 + 0.15 * math.sin(t * 130)) * math.sin(math.pi * p) ** 2
        elif name == 'hit':
            value = (noise * 0.3 + math.sin(math.tau * 95 * t)) * math.exp(-t * 35)
        elif name == 'pickup':
            frequency = 620 if p < 0.5 else 880
            value = math.sin(math.tau * frequency * t) * 0.3 * math.sin(math.pi * (p * 2 % 1))
        elif name == 'harvest':
            value = (math.sin(math.tau * (110 * t + 100 * t * t)) * 0.45 + noise * 0.12) * math.sin(math.pi * p)
        elif name == 'down':
            value = (math.sin(math.tau * (230 * t - 190 * t * t)) * 0.55 + noise * 0.1) * (1 - p) ** 2
        elif name == 'revive':
            notes = [330, 440, 550]
            part = min(2, int(p * 3))
            value = math.sin(math.tau * notes[part] * t) * 0.35 * math.sin(math.pi * (p * 3 % 1))
        elif name == 'wave':
            value = math.sin(math.tau * (520 * t + 70 * t * t)) * 0.3 * (math.sin(math.pi * p * 3) ** 8)
        else:
            value = (math.sin(math.tau * 160 * t) * 0.35 + noise * 0.15) * math.exp(-t * 18)
        samples.append(value * attack * release)
    peak = max(abs(x) for x in samples)
    return [int(max(-1, min(1, x * 0.65 / max(0.65, peak))) * 32767) for x in samples]


def main():
    target = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
    target.mkdir(parents=True, exist_ok=True)
    for name, duration in SOUNDS.items():
        samples = synth(name, duration)
        with wave.open(str(target / (name + '.wav')), 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(struct.pack('<' + 'h' * len(samples), *samples))
        print(name, len(samples), 'samples')


if __name__ == '__main__':
    main()
