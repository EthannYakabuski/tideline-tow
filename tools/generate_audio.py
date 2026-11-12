"""Rebuild Tideline Tow's original, sample-free score using Python's standard library.

The four arrangements are deliberately composed, not randomized note generators.
Kenney effects are copied separately and retain their original CC0 notices.
Run: python tools/generate_audio.py
"""
from __future__ import annotations

import array
import hashlib
import json
import math
from pathlib import Path
import random
import struct
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio" / "music"
RATE = 22050
TAU = math.tau


def hz(note: float) -> float:
    return 440.0 * 2.0 ** ((note - 69) / 12.0)


class Score:
    def __init__(self, bars: int, bpm: int, seed: int):
        self.bpm = bpm
        self.beat = 60.0 / bpm
        self.frames = round(bars * 4 * self.beat * RATE)
        self.left = array.array("f", [0]) * self.frames
        self.right = array.array("f", [0]) * self.frames
        self.rng = random.Random(seed)
        self.events = 0

    def add(self, beat: float, sound: array.array, gain: float, pan: float = 0.0):
        start = round(beat * self.beat * RATE)
        lg = math.sqrt((1.0 - pan) * 0.5) * gain
        rg = math.sqrt((1.0 + pan) * 0.5) * gain
        for i, sample in enumerate(sound):
            pos = (start + i) % self.frames
            self.left[pos] += sample * lg
            self.right[pos] += sample * rg
        self.events += 1

    def note(self, beat: float, note: int, duration: float, gain: float,
             kind: str = "plucked", pan: float = 0.0):
        n = round(duration * self.beat * RATE)
        frequency = hz(note)
        data = array.array("f")
        # Fixed partials emulate plucked strings / soft vibraphone, with no samples.
        for i in range(n):
            t = i / RATE
            s = i / max(1, n - 1)
            attack = min(1.0, t / (0.045 if kind == "pad" else 0.006))
            release = min(1.0, (1 - s) * (12 if kind == "pad" else 25))
            phase = TAU * frequency * t
            if kind == "bass":
                v = (math.sin(phase) + 0.20 * math.sin(phase * 2) + 0.05 * math.sin(phase * 3))
                env = math.exp(-s * 2.6)
            elif kind == "pad":
                v = (math.sin(phase) + 0.20 * math.sin(phase * 2) + 0.12 * math.sin(phase * 3))
                env = 0.7 + 0.3 * math.sin(math.pi * s)
            elif kind == "bell":
                v = (math.sin(phase) + 0.32 * math.sin(phase * 2.0) * math.exp(-t * 7)
                     + 0.16 * math.sin(phase * 3.0) * math.exp(-t * 11))
                env = math.exp(-s * 5.0)
            elif kind == "reed":
                v = (math.sin(phase + 0.018 * math.sin(TAU * 4.6 * t))
                     + 0.20 * math.sin(phase * 3) + 0.08 * math.sin(phase * 5))
                env = math.exp(-s * 1.8)
            else:
                v = (math.sin(phase) + 0.36 * math.sin(phase * 2) * math.exp(-t * 9)
                     + 0.15 * math.sin(phase * 3) * math.exp(-t * 17))
                env = math.exp(-s * 4.1)
            data.append(v * env * attack * release)
        self.add(beat, data, gain, pan)

    def percussion(self, beat: float, kind: str, gain: float, pan: float = 0):
        duration = {"kick": 0.24, "brush": 0.12, "wood": 0.07, "shaker": 0.05}[kind]
        n = int(duration * RATE)
        data = array.array("f")
        last = 0.0
        for i in range(n):
            t = i / RATE
            envelope = math.exp(-t * {"kick": 24, "brush": 34, "wood": 55, "shaker": 65}[kind])
            if kind == "kick":
                v = math.sin(TAU * (52 * t + 3.8 * (1 - math.exp(-t * 30))))
            elif kind == "wood":
                v = math.sin(TAU * 960 * t) * 0.6 + math.sin(TAU * 1437 * t) * 0.3
            else:
                noise = self.rng.uniform(-1, 1)
                # Gentle high-pass noise; a little brush, never a loud hi-hat.
                v = (noise - last) * 0.55
                last = noise
            data.append(v * envelope * min(1.0, t / 0.0015))
        self.add(beat, data, gain, pan)

    def write(self, name: str, title: str, description: str):
        # Circular early-reflection taps retain the exact loop and soften the dry synths.
        dry_l, dry_r = array.array("f", self.left), array.array("f", self.right)
        for delay, decay in [(0.113, 0.12), (0.227, 0.075), (0.347, 0.035)]:
            offset = round(delay * RATE)
            for i in range(self.frames):
                j = (i - offset) % self.frames
                self.left[i] += dry_r[j] * decay
                self.right[i] += dry_l[j] * decay
        energy = sum(x * x for x in self.left) + sum(x * x for x in self.right)
        rms_before = math.sqrt(energy / (self.frames * 2))
        peak_before = max(max(abs(x) for x in self.left), max(abs(x) for x in self.right))
        # About -22 dBFS RMS leaves ample room for clear reward and collision sounds.
        gain = min(10 ** (-22 / 20) / rms_before, 0.55 / peak_before)
        pcm = array.array("h")
        for l, r in zip(self.left, self.right):
            pcm.append(round(l * gain * 32767))
            pcm.append(round(r * gain * 32767))
        if sys.byteorder != "little":
            pcm.byteswap()
        path = OUT / f"{name}.wav"
        with wave.open(str(path), "wb") as f:
            f.setnchannels(2)
            f.setsampwidth(2)
            f.setframerate(RATE)
            f.writeframes(pcm.tobytes())
        # Standard RIFF smpl forward-loop cue. Godot can import this without special code.
        smpl = struct.pack("<9I", 0, 0, round(1_000_000_000 / RATE), 60, 0, 0, 0, 1, 0)
        smpl += struct.pack("<6I", 0, 0, 0, self.frames - 1, 0, 0)
        raw = bytearray(path.read_bytes())
        raw.extend(b"smpl" + struct.pack("<I", len(smpl)) + smpl)
        struct.pack_into("<I", raw, 4, len(raw) - 8)
        path.write_bytes(raw)
        seam = max(abs(self.left[-1] - self.left[0]), abs(self.right[-1] - self.right[0])) * gain
        result = {
            "file": str(path.relative_to(ROOT)).replace("\\", "/"), "title": title,
            "description": description, "composer": "Original Tideline Tow score",
            "license": "Apache-2.0", "bpm": self.bpm, "bars": 16,
            "duration_seconds": round(self.frames / RATE, 6), "sample_rate": RATE,
            "channels": 2, "bits": 16, "loop": "forward, full file; embedded smpl cue",
            "events": self.events, "rms_dbfs": round(20 * math.log10(rms_before * gain), 3),
            "peak_dbfs": round(20 * math.log10(peak_before * gain), 3),
            "max_boundary_step": round(seam, 7), "sha256": hashlib.sha256(raw).hexdigest(),
        }
        print(json.dumps(result))
        return result


def compose(name: str, bpm: int, root: int, chords: list[list[int]], melody: list[list[int]],
            title: str, description: str, lead: str, groove: str, seed: int):
    score = Score(16, bpm, seed)
    for bar in range(16):
        chord = chords[bar % len(chords)]
        base = bar * 4
        # Eight-bar call and response repeated with a register/texture lift.
        for index, tone in enumerate(chord[:3]):
            score.note(base + index * 0.045, root + tone, 3.8, 0.033, "pad", [-0.6, 0.0, 0.6][index])
        bass = root + chord[0] - 24
        score.note(base, bass, 1.65, 0.22, "bass", -0.08)
        score.note(base + 2.0, bass + 7, 1.6, 0.17, "bass", 0.08)
        for off, tone in zip([0.5, 1.5, 2.5, 3.5], [chord[0], chord[1], chord[2], chord[1]]):
            score.note(base + off, root + tone, 0.95, 0.065, "plucked", -0.28 if off < 2 else 0.28)
        phrase = melody[bar % len(melody)]
        spacing = 4 / len(phrase)
        for index, tone in enumerate(phrase):
            if tone == -99:
                continue
            length = spacing * (1.65 if index == len(phrase) - 1 else 0.9)
            score.note(base + index * spacing, root + tone + 12, length, 0.12 if groove == "menu" else 0.14, lead, 0.08)
            if bar >= 12 and index in (0, 2):
                score.note(base + index * spacing + 0.08, root + tone, length, 0.035, "bell", -0.35)
        if groove != "menu":
            score.percussion(base, "kick", 0.15)
            score.percussion(base + 2, "kick", 0.12)
            for off in [1, 3]:
                score.percussion(base + off, "brush", 0.095, 0.1)
                score.percussion(base + off + 0.015, "wood", 0.04, -0.2)
            for idx in range(8):
                score.percussion(base + idx * 0.5 + (0.05 if idx % 2 else 0), "shaker", 0.022 if idx % 2 else 0.034, 0.38)
            if groove == "copper" and bar % 4 == 3:
                for off in [2.75, 3.25, 3.75]:
                    score.percussion(base + off, "wood", 0.055, -0.42)
        else:
            for off in [1, 3]:
                score.percussion(base + off, "shaker", 0.023, 0.4)
        if groove == "lantern":
            score.note(base + 3.5, root + chord[2] + 24, 1.5, 0.035, "bell", -0.45)
    return score.write(name, title, description)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    results = []
    results.append(compose("menu", 88, 60,
        [[0, 4, 7], [9, 12, 16], [5, 9, 12], [7, 11, 14]],
        [[7, 4, 2, 0], [4, 7, 9, -99], [9, 7, 5, 4], [2, 4, 2, -99],
         [0, 4, 7, 12], [11, 9, 7, 4], [5, 4, 2, 0], [2, -99, 7, -99]],
        "The Harbor Is Home", "Warm mallets, gently plucked strings and soft sustained harbor chords.",
        "bell", "menu", 121101))
    results.append(compose("sunwake", 108, 62,
        [[0, 4, 7], [7, 11, 14], [9, 12, 16], [5, 9, 12]],
        [[0, 4, 7, 4, 2, 4, 7, 9], [7, 4, 2, -99], [4, 7, 9, 12, 9, 7, 4, 2], [5, 4, 2, 0],
         [0, 2, 4, 7, 9, 7, 4, -99], [2, 4, 7, 11], [12, 9, 7, 4, 7, 9, 7, 4], [5, 4, 2, -99]],
        "Sunwake Skipping Rope", "A buoyant plucked tune with light hand percussion and an eight-bar reply.",
        "plucked", "sunwake", 121102))
    results.append(compose("copperdock", 116, 57,
        [[0, 3, 7], [5, 9, 12], [7, 10, 14], [0, 3, 7]],
        [[0, 3, 7, 10, 7, 3, 5, 7], [9, 7, 5, -99], [7, 10, 12, 14, 12, 10, 7, 5], [3, 0, 3, -99],
         [0, 3, 5, 7, 10, 7, 5, 3], [5, 7, 9, -99], [10, 7, 5, 7, 10, 12, 10, 7], [3, 5, 3, 0]],
        "Brass and Buoys", "A restrained reed-and-woodblock work song with a mild Dorian lift.",
        "reed", "copper", 121103))
    results.append(compose("lantern", 96, 59,
        [[0, 3, 7], [8, 12, 15], [5, 8, 12], [7, 10, 14]],
        [[7, 3, 0, -99], [8, 7, 3, -99], [5, 8, 12, 10], [7, 5, 3, -99],
         [0, 3, 7, 10], [12, 10, 8, 7], [8, 5, 3, 0], [2, 3, 2, -99]],
        "Last Lantern Home", "Moonlit bell phrases, low warm chords and distant soft deck percussion.",
        "bell", "lantern", 121104))
    manifest = {"generator": "tools/generate_audio.py", "version": 1,
        "provenance": "Original authored melodies, harmony and synthesis; no external musical samples.",
        "validation": "PCM structure, levels and loop boundaries measured. Listening and physical-device mix require human review.",
        "tracks": results}
    (OUT / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
