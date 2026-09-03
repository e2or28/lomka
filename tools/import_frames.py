#!/usr/bin/env python3
"""Набор кадров анимации -> общий холст с общей системой координат.

Обрезанные каждый по себе кадры дают персонажа, который дёргается на месте.
Художник присылает их разными файлами разного размера, с разбросом
масштаба до двадцати процентов — сетку апскейла в таком виде уже не найти,
поэтому масштаб здесь берётся не из неё, а из роста силуэта.

Выравнивание — по двум опорам, не зависящим от позы: низ силуэта (пол под
ногами, root_y) и центр туловища, полоса 35–55% высоты силуэта (torso_x).
Центр всего силуэта для этого не годится — он гуляет вместе с махом рук.

    tools/import_frames.py ВЫХОД_ПРЕФИКС ВХОД... [--height N]

  --height N     целевой рост силуэта в пикселях (по умолчанию 156)
  --canvas WxH   размер общего холста (по умолчанию 128x192)
  --root-y N     линия пола на холсте (по умолчанию 174)
  --torso-x N    куда садится центр туловища (по умолчанию 58)
  --start N      с какого номера нумеровать кадры (по умолчанию 1)

Значения по умолчанию совпадают с art/player_layers.json: новый набор
обязан сесть в ту же посадку, иначе при смене оружия персонаж прыгнет.

    tools/import_frames.py art/player_colt_walk ~/Downloads/кадры/*.png
"""

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_sprite import decode, despeckle, encode  # noqa: E402

TORSO_BAND = (0.35, 0.55)

# Щедрый намеренно: часть кадров на нарисованной шахматке «прозрачности» —
# два светлых оттенка, которые оба обязаны считаться фоном. Персонажу это
# не грозит: самое светлое в нём, воротник, отстоит от белого втрое дальше.
FLOOD_TOLERANCE = 90

# Темнее этого — паспарту, а не фон рисунка.
MATTE_LEVEL = 120

ALPHA_SHARE = 0.01


def decode_rgba(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """Прозрачный пиксель, прочитанный как rgb, становится чёрным, и фоном
    объявляется чёрный — читать нужно с альфой."""
    import subprocess

    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True)
    width, height = (int(v) for v in probe.stdout.strip().split("x"))
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
         "-pix_fmt", "rgba", "-"], capture_output=True, check=True).stdout
    pixels = np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4)
    return pixels[:, :, :3].astype(np.int16), pixels[:, :, 3]


def strip_matte(image: np.ndarray, alpha: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Срезать тёмную кайму паспарту: иначе она станет фоновым цветом, и
    заливка от краёв остановится об неё, не дойдя до настоящего фона."""
    corner = image[0, 0]
    if int(corner.sum()) > MATTE_LEVEL:
        return image, alpha
    inked = np.abs(image - corner).sum(axis=2) > 40
    rows = np.where(inked.any(axis=1))[0]
    columns = np.where(inked.any(axis=0))[0]
    if rows.size == 0 or columns.size == 0:
        return image, alpha
    box = (slice(rows[0], rows[-1] + 1), slice(columns[0], columns[-1] + 1))
    return image[box], alpha[box]


def _flood_from_edges(similar: np.ndarray) -> np.ndarray:
    """Заливка от краёв по отрезкам строк, а не попиксельно: на полутора
    миллионах точек попиксельная заливка в Python стоит десятки секунд."""
    height, width = similar.shape
    filled = np.zeros_like(similar)
    stack: list[tuple[int, int]] = []

    for x in range(width):
        for y in (0, height - 1):
            if similar[y, x] and not filled[y, x]:
                stack.append((x, y))
    for y in range(height):
        for x in (0, width - 1):
            if similar[y, x] and not filled[y, x]:
                stack.append((x, y))

    while stack:
        x, y = stack.pop()
        if filled[y, x] or not similar[y, x]:
            continue

        left = x
        while left > 0 and similar[y, left - 1] and not filled[y, left - 1]:
            left -= 1
        right = x
        while right < width - 1 and similar[y, right + 1] and not filled[y, right + 1]:
            right += 1
        filled[y, left:right + 1] = True

        for neighbour in (y - 1, y + 1):
            if neighbour < 0 or neighbour >= height:
                continue
            row_similar = similar[neighbour, left:right + 1]
            row_filled = filled[neighbour, left:right + 1]
            for offset in np.where(row_similar & ~row_filled)[0]:
                stack.append((left + int(offset), neighbour))
    return filled


def content_mask(image: np.ndarray, alpha: np.ndarray) -> np.ndarray:
    """Готовая альфа берётся как есть. Без неё — заливка от краёв, а не порог
    по цвету: порог объявил бы фоном и белую рубашку на белом листе."""
    if (alpha < 50).mean() > ALPHA_SHARE:
        return alpha > 128

    background = image[0, 0].astype(np.int16)
    similar = np.abs(image - background).sum(axis=2) <= FLOOD_TOLERANCE
    return ~_flood_from_edges(similar)


def silhouette(mask: np.ndarray) -> tuple[int, int, int, int]:
    """Рамка рисунка: left, top, right, bottom включительно."""
    rows = np.where(mask.any(axis=1))[0]
    columns = np.where(mask.any(axis=0))[0]
    if rows.size == 0 or columns.size == 0:
        raise SystemExit("кадр пустой: не найдено ничего, кроме фона")
    return int(columns[0]), int(rows[0]), int(columns[-1]), int(rows[-1])


def torso_center(mask: np.ndarray, top: int, bottom: int) -> float:
    """Полоса между плечами и бёдрами не участвует в махе рук и выносе
    ноги, поэтому её центр стоит на месте весь цикл ходьбы."""
    height = bottom - top + 1
    band_top = top + int(height * TORSO_BAND[0])
    band_bottom = top + int(height * TORSO_BAND[1])
    band = mask[band_top:band_bottom + 1]
    columns = np.where(band.any(axis=0))[0]
    if columns.size == 0:
        raise SystemExit("не найдено туловище: кадр обрезан или пустой")
    return float(columns[0] + columns[-1]) / 2.0


def resample(image: np.ndarray, mask: np.ndarray, scale: float) -> tuple[np.ndarray, np.ndarray]:
    """Выборкой ближайшего пикселя, без сглаживания — оно размыло бы края."""
    src_h, src_w = mask.shape
    height = max(int(round(src_h * scale)), 1)
    width = max(int(round(src_w * scale)), 1)
    ys = (np.arange(height) / scale).astype(int).clip(0, src_h - 1)
    xs = (np.arange(width) / scale).astype(int).clip(0, src_w - 1)
    return image[ys][:, xs], mask[ys][:, xs]


def place(image: np.ndarray, mask: np.ndarray, canvas: tuple[int, int],
          root_y: int, torso_x: int) -> np.ndarray:
    """Положить кадр на общий холст по двум опорам: пол и центр туловища."""
    left, top, right, bottom = silhouette(mask)
    center = torso_center(mask, top, bottom)

    width, height = canvas
    out = np.zeros((height, width, 4), dtype=np.uint8)

    dx = int(round(torso_x - center))
    dy = int(round(root_y - bottom))

    for y in range(top, bottom + 1):
        ty = y + dy
        if ty < 0 or ty >= height:
            continue
        for x in range(left, right + 1):
            tx = x + dx
            if tx < 0 or tx >= width or not mask[y, x]:
                continue
            out[ty, tx, :3] = image[y, x]
            out[ty, tx, 3] = 255
    return out


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("target_prefix", type=Path,
                        help="префикс выходных файлов: art/player_colt_walk -> _1.png, _2.png")
    parser.add_argument("sources", type=Path, nargs="+")
    parser.add_argument("--height", type=int, default=156)
    parser.add_argument("--canvas", default="128x192")
    parser.add_argument("--root-y", type=int, default=174)
    parser.add_argument("--torso-x", type=int, default=58)
    parser.add_argument("--start", type=int, default=1)
    args = parser.parse_args()

    canvas = tuple(int(v) for v in args.canvas.lower().split("x"))
    if len(canvas) != 2:
        print("--canvas задаётся как ШИРИНАxВЫСОТА, например 128x192", file=sys.stderr)
        return 1

    missing = [s for s in args.sources if not s.exists()]
    if missing:
        for s in missing:
            print(f"нет файла: {s}", file=sys.stderr)
        return 1

    args.target_prefix.parent.mkdir(parents=True, exist_ok=True)
    print(f"целевой рост {args.height} px, холст {canvas[0]}x{canvas[1]}, "
          f"пол y={args.root_y}, центр туловища x={args.torso_x}")

    for index, source in enumerate(args.sources, start=args.start):
        image, alpha = strip_matte(*decode_rgba(source))
        drawn_alpha = (alpha < 50).mean() > ALPHA_SHARE
        mask = content_mask(image, alpha)
        left, top, right, bottom = silhouette(mask)
        raw_height = bottom - top + 1

        scale = args.height / raw_height
        small_image, small_mask = resample(image, mask, scale)
        frame = place(small_image, small_mask, canvas, args.root_y, args.torso_x)

        if not drawn_alpha:
            frame = despeckle(frame, image[0, 0].astype(np.int16))

        target = args.target_prefix.with_name(f"{args.target_prefix.name}_{index}.png")
        encode(frame, target)

        placed = silhouette(frame[:, :, 3] > 0)
        print(f"  {source.name}")
        print(f"    исходник {image.shape[1]}x{image.shape[0]}, силуэт {right - left + 1}x{raw_height}"
              f"  масштаб {scale:.3f}")
        print(f"    -> {target}  силуэт x{placed[0]}..{placed[2]} y{placed[1]}..{placed[3]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
