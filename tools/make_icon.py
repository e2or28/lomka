#!/usr/bin/env python3
"""Иконка приложения из спрайта персонажа.

Персонаж вытянутый, а иконка квадратная, поэтому он вписывается в квадрат
целиком, с полями и на тёмном фоне — том же, что у пола комнаты. Растягивать
нельзя: пропорции поедут, и на маленьком размере это первое, что заметно.

    python3 tools/make_icon.py art/player.png icon.png [--size 1024]
"""

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

BACKGROUND = (0x1B, 0x1A, 0x1E, 255)
MARGIN = 0.12


def load(path: Path) -> np.ndarray:
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True).stdout.strip()
    width, height = (int(v) for v in probe.split("x"))
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
         "-pix_fmt", "rgba", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4)


def trim(sprite: np.ndarray) -> np.ndarray:
    solid = sprite[:, :, 3] > 0
    rows = np.where(solid.any(axis=1))[0]
    columns = np.where(solid.any(axis=0))[0]
    return sprite[rows[0]:rows[-1] + 1, columns[0]:columns[-1] + 1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--size", type=int, default=1024)
    args = parser.parse_args()

    sprite = trim(load(args.source))
    usable = int(args.size * (1.0 - MARGIN * 2))
    factor = max(min(usable // sprite.shape[0], usable // sprite.shape[1]), 1)
    scaled = np.repeat(np.repeat(sprite, factor, axis=0), factor, axis=1)

    canvas = np.zeros((args.size, args.size, 4), dtype=np.uint8)
    canvas[:, :] = BACKGROUND
    top = (args.size - scaled.shape[0]) // 2
    left = (args.size - scaled.shape[1]) // 2
    area = canvas[top:top + scaled.shape[0], left:left + scaled.shape[1]]
    alpha = scaled[:, :, 3:4] / 255.0
    area[:, :, :3] = (scaled[:, :, :3] * alpha + area[:, :, :3] * (1 - alpha)).astype(np.uint8)

    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{args.size}x{args.size}", "-i", "-", "-y", str(args.target)],
        input=canvas.tobytes(), check=True)
    print(f"  {args.target}  {args.size}x{args.size} (спрайт увеличен в {factor} раз)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
