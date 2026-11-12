"""
原创氛围 BGM 生成器（仅 Python 标准库，无任何第三方音频素材）。
生成 public/audio/ambient.wav；随后用 ffmpeg 转成 ambient.mp3 供 Remotion 使用。

    python src/scripts/make-bgm.py
    ffmpeg -y -i public/audio/ambient.wav -codec:a libmp3lame -b:a 128k public/audio/ambient.mp3

做法：四组柔和七和弦铺底（轻微 detune 做厚度）+ 稀疏的衰减拨音，
再叠一层短反馈延迟当空间感，最后做首尾淡入淡出。全部波形由数学函数实时合成。
"""

import array
import math
import wave
from pathlib import Path

SR = 44100
DUR = 45.5
N = int(SR * DUR)
OUT = Path(__file__).resolve().parents[2] / "public" / "audio" / "ambient.wav"

CHORDS = [
    [60, 64, 67, 71],  # Cmaj7
    [57, 60, 64, 67],  # Am7
    [53, 57, 60, 64],  # Fmaj7
    [55, 59, 62, 65],  # G7
]
SEG = DUR / 4.0


def midi(m: float) -> float:
    return 440.0 * (2.0 ** ((m - 69) / 12.0))


def smooth(x: float) -> float:
    x = max(0.0, min(1.0, x))
    return x * x * (3.0 - 2.0 * x)


buf = [0.0] * N

# ---- 铺底和弦 ----
for ci, chord in enumerate(CHORDS):
    start = ci * SEG
    i0 = max(0, int((start - 0.5) * SR))
    i1 = min(N, int((start + SEG + 0.5) * SR))
    for m in chord:
        for detune in (0.9985, 1.0015):
            inc = 2.0 * math.pi * midi(m) * detune / SR
            phase = 0.0
            for i in range(i0, i1):
                t = i / SR - start
                env = smooth(t / 2.5) * smooth((SEG + 1.0 - t) / 2.5)
                buf[i] += 0.052 * env * math.sin(phase)
                phase += inc

# ---- 稀疏拨音（带谐波 + 指数衰减，模拟柔和的钢琴/钟琴质感）----
for k in range(24):
    t0 = 1.2 + k * 1.85
    if t0 >= DUR - 2.5:
        break
    ci = min(3, int(t0 / SEG))
    f = midi(CHORDS[ci][(k * 2) % 4] + 12)
    i0 = int(t0 * SR)
    i1 = min(N, i0 + int(2.2 * SR))
    for j in range(i1 - i0):
        tt = j / SR
        env = math.exp(-tt * 3.2) * (1.0 - math.exp(-tt * 80.0))
        v = (
            math.sin(2 * math.pi * f * tt)
            + 0.32 * math.sin(2 * math.pi * 2 * f * tt)
            + 0.12 * math.sin(2 * math.pi * 3 * f * tt)
        )
        buf[i0 + j] += 0.10 * env * v

# ---- 轻混响（短反馈延迟）----
delay = int(0.19 * SR)
line = [0.0] * delay
for i in range(N):
    idx = i % delay
    d = line[idx]
    buf[i] += 0.22 * d
    line[idx] = buf[i] + 0.30 * d

# ---- 归一化 + 首尾淡入淡出 + 写 WAV ----
peak = max(abs(x) for x in buf) or 1.0
gain = 0.82 / peak
fade = int(1.5 * SR)
stereo = array.array("h")
for i, x in enumerate(buf):
    f = smooth(i / fade) if i < fade else 1.0
    if i > N - fade:
        f = min(f, smooth((N - i) / fade))
    v = int(max(-32767, min(32767, x * gain * f * 32767)))
    stereo.append(v)
    stereo.append(v)

OUT.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(OUT), "wb") as w:
    w.setnchannels(2)
    w.setsampwidth(2)
    w.setframerate(SR)
    w.writeframes(stereo.tobytes())

print(f"BGM -> {OUT} ({DUR:.1f}s, {SR}Hz, stereo)")
