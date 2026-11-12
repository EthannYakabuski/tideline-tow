"""Check shipped audio bytes and seamless loop cues without external dependencies."""
from pathlib import Path
import array
import hashlib
import json
import math
import struct
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]
audio_root = ROOT / "assets" / "audio"
manifest = json.loads((audio_root / "music" / "manifest.json").read_text())
assert len(manifest["tracks"]) == 4, "Four distinct menu/district arrangements are required"
hashes = set()
checks = 0

for track in manifest["tracks"]:
    path = ROOT / track["file"]
    data = path.read_bytes()
    digest = hashlib.sha256(data).hexdigest()
    assert digest == track["sha256"], f"Changed music bytes: {path.name}"
    hashes.add(digest)
    assert data[:4] == b"RIFF" and data[8:12] == b"WAVE", path.name
    assert struct.unpack_from("<I", data, 4)[0] == len(data) - 8, path.name
    with wave.open(str(path)) as stream:
        assert (stream.getnchannels(), stream.getsampwidth(), stream.getframerate()) == (2, 2, 22050)
        frames = stream.getnframes()
        assert frames == round(16 * 4 * 60 / track["bpm"] * stream.getframerate())
        pcm = array.array("h", stream.readframes(frames))
    if sys.byteorder != "little":
        pcm.byteswap()
    peak = max(abs(v) for v in pcm) / 32768
    rms = math.sqrt(sum(v * v for v in pcm) / len(pcm)) / 32768
    dc = sum(pcm) / (len(pcm) * 32768)
    boundary = max(abs(pcm[-2] - pcm[0]), abs(pcm[-1] - pcm[1])) / 32768
    assert 0.15 < peak < 0.58, f"Insufficient musical dynamic range/headroom: {path.name}"
    assert -23 < 20 * math.log10(rms) < -21, f"Music loudness mismatch: {path.name}"
    assert abs(dc) < 0.001, f"DC offset: {path.name}"
    assert boundary < 0.01, f"Loop boundary discontinuity: {path.name}"
    pos, loop = 12, None
    while pos + 8 <= len(data):
        tag = data[pos:pos + 4]
        length = struct.unpack_from("<I", data, pos + 4)[0]
        if tag == b"smpl":
            loop = data[pos + 8:pos + 8 + length]
        pos += 8 + length + (length % 2)
    assert loop is not None and len(loop) >= 60, f"Missing embedded loop: {path.name}"
    assert struct.unpack_from("<I", loop, 28)[0] == 1
    assert struct.unpack_from("<6I", loop, 36)[1:] == (0, 0, frames - 1, 0, 0)
    checks += 12
    print(f"PASS {path.name}: {frames / 22050:.2f}s, peak {20*math.log10(peak):.2f} dBFS, RMS {20*math.log10(rms):.2f} dBFS, boundary {boundary:.6f}")
assert len(hashes) == 4
checks += 1

effects = json.loads((audio_root / "effects_manifest.json").read_text(encoding="utf-8-sig"))
assert {Path(e["file"]).stem for e in effects} == {"hook", "delivery", "bump", "click", "win", "fail", "upgrade"}
checks += 1
for effect in effects:
    path = ROOT / effect["file"]
    data = path.read_bytes()
    assert hashlib.sha256(data).hexdigest() == effect["sha256"] == effect["source_sha256"], path.name
    assert data.startswith(b"OggS") and b"\x01vorbis" in data[:128], path.name
    assert (ROOT / "LICENSES" / f"{effect['source_pack']}.txt").is_file(), path.name
    # Ogg page granules provide lossless duration metadata without an audio decoder.
    identification = data.index(b"\x01vorbis")
    sample_rate = struct.unpack_from("<I", data, identification + 12)[0]
    pos, granule = 0, 0
    while pos < len(data):
        assert data[pos:pos + 4] == b"OggS", f"Invalid Ogg page: {path.name}"
        segments = data[pos + 26]
        granule = max(granule, struct.unpack_from("<Q", data, pos + 6)[0])
        pos += 27 + segments + sum(data[pos + 27:pos + 27 + segments])
    duration = granule / sample_rate
    assert 0.025 < duration < 4, f"Unexpected UI effect duration: {path.name}"
    checks += 4
    print(f"PASS {path.name}: {duration:.3f}s, unmodified Kenney CC0 Vorbis")

print(f"AUDIO_VALIDATION_PASS: {checks} structural, provenance, level and loop assertions")
