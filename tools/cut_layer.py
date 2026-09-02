#!/usr/bin/env python3
"""Вырезать часть спрайта в отдельный слой на том же холсте.

Слои персонажа лежат на общем холсте 128x192 в одной системе координат —
поэтому вырезанный кусок нельзя обрезать по содержимому: он обязан остаться
на своём месте, иначе не совместится с остальными.

    tools/cut_layer.py ВХОД ВЫХОД --top 19 --bottom 67

Границы ищутся по спрайту, а не на глаз: у профильной стойки шея видна как
минимум ширины силуэта, и голова кончается ровно там.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np


def load(path: Path):
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True)
    width, height = (int(v) for v in probe.stdout.strip().split("x"))
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
         "-pix_fmt", "rgba", "-"], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4).copy()


def save(pixels: np.ndarray, path: Path) -> None:
    height, width = pixels.shape[:2]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{width}x{height}", "-i", "-", "-y", str(path)],
        input=pixels.tobytes(), check=True)


def find_neck(pixels: np.ndarray, search_to: int) -> int:
    """Шея — самое узкое место силуэта в верхней части. По нему и режем."""
    solid = pixels[:, :, 3] > 8
    rows = np.where(solid.any(axis=1))[0]
    if rows.size == 0:
        raise SystemExit("на картинке нет ничего, кроме прозрачного")
    top = int(rows[0])
    widths = [(int(solid[y].sum()), y) for y in range(top + 8, min(top + search_to, pixels.shape[0]))]
    return min(widths)[1] if widths else top


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--top", type=int, default=0)
    parser.add_argument("--bottom", type=int, default=-1)
    parser.add_argument("--auto-neck", action="store_true",
                        help="найти нижнюю границу по самому узкому месту")
    args = parser.parse_args()

    if not args.source.exists():
        print(f"нет файла: {args.source}", file=sys.stderr)
        return 1

    pixels = load(args.source)
    bottom = args.bottom
    if args.auto_neck:
        bottom = find_neck(pixels, 80)

    cut = np.zeros_like(pixels)
    end = pixels.shape[0] if bottom < 0 else min(bottom + 1, pixels.shape[0])
    cut[args.top:end] = pixels[args.top:end]

    args.target.parent.mkdir(parents=True, exist_ok=True)
    save(cut, args.target)

    solid = np.where(cut[:, :, 3] > 8)
    print(f"{args.source.name} -> {args.target}")
    print(f"  срез:    y {args.top}..{end - 1}")
    print(f"  занято:  x {solid[1].min()}..{solid[1].max()}, y {solid[0].min()}..{solid[0].max()}")
    print(f"  холст:   {cut.shape[1]}x{cut.shape[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
