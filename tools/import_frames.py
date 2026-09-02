#!/usr/bin/env python3
"""Набор кадров анимации -> общий холст с общей системой координат.

Зачем отдельно от import_sprite.py. Одиночный спрайт можно обрезать по
рисунку: у него нет соседей, с которыми надо совпадать. У кадров анимации
всё наоборот — обрезанные каждый по себе, они дают персонажа, который
дёргается на месте: ноги гуляют по вертикали, тело плавает по горизонтали.
Кадры обязаны лежать на общем холсте и в общей системе координат, иначе
анимация разваливается независимо от того, как хорошо нарисован каждый кадр.

Что этому мешает на практике. Кадры приходят от художника разными файлами
разного размера: 1024x1536, 1108x1420, 967x1627. Причина не в рисунке, а в
пересохранении: масштаб гуляет между кадрами до двадцати процентов, а
пиксельная сетка апскейла размывается интерполяцией и перестаёт читаться —
расстояния между границами цвета расходятся от шести до десяти пикселей,
и определять по ним шаг, как это делает import_sprite.py, уже нельзя.

Поэтому масштаб здесь берётся не из сетки, а из роста силуэта: все кадры
приводятся к одному росту в пикселях. Осознанная цена — теряется настоящее
приседание на шаге, у нарисованных кадров оно около трёх процентов. Взамен
уходит случайный разброс масштаба в двадцать, который читается как скачок
камеры и портит анимацию куда заметнее.

Выравнивание идёт по двум опорам, обе не зависят от позы:

  * низ силуэта — линия пола под ногами, садится на root_y холста;
  * центр туловища — середина полосы от 35% до 55% высоты силуэта, садится
    на torso_x. Именно туловища, а не всего силуэта: центр всего силуэта
    гуляет вместе с махом рук и выносом ноги, и персонаж на ходу виляет.

    tools/import_frames.py ВЫХОД_ПРЕФИКС ВХОД... [--height N]

  --height N     целевой рост силуэта в пикселях (по умолчанию 156)
  --canvas WxH   размер общего холста (по умолчанию 128x192)
  --root-y N     линия пола на холсте (по умолчанию 174)
  --torso-x N    куда садится центр туловища (по умолчанию 58)
  --start N      с какого номера нумеровать кадры (по умолчанию 1)

Значения по умолчанию совпадают с art/player_layers.json и с уже стоящими
в игре кадрами ходьбы: новый набор обязан сесть в ту же посадку, иначе при
смене оружия персонаж прыгнет.

    tools/import_frames.py art/player_colt_walk ~/Downloads/кадры/*.png
"""

import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_sprite import decode, despeckle, encode  # noqa: E402

# Полоса силуэта, которая считается туловищем. Голова выше, ноги ниже, и
# обе двигаются: голова качается на шаге, ноги расходятся.
TORSO_BAND = (0.35, 0.55)

# Насколько цвет должен отличаться от фонового, чтобы заливка через него
# не прошла. Допуск щедрый намеренно: часть кадров приходит не на ровном
# фоне, а на нарисованной шахматке «прозрачности» — два светлых оттенка,
# которые обязаны считаться фоном оба. Персонажу это ничем не грозит:
# самое светлое в нём, воротник рубашки, отстоит от белого втрое дальше.
FLOOD_TOLERANCE = 90

# Темнее этого — паспарту, а не фон рисунка.
MATTE_LEVEL = 120

# С какой доли прозрачных пикселей считать, что альфа-канал осмысленный,
# а не формальный.
ALPHA_SHARE = 0.01


def decode_rgba(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """Картинка -> (rgb, alpha).

    Читать всегда с альфой, а не по цвету фона: кадры одного и того же
    набора приходят и с прозрачностью, и без неё. Прозрачный пиксель,
    прочитанный как rgb, становится чёрным — и тогда фоном объявляется
    чёрный, а вместе с ним волосы, брюки и ботинки.
    """
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
    """Срезать тёмную рамку по краям картинки.

    Часть кадров приходит в паспарту: тёмная кайма в пару десятков пикселей
    вокруг рисунка, который сам лежит на белом. Если этого не заметить,
    фоновым цветом окажется цвет каймы, и заливка от краёв остановится об
    неё, так и не добравшись до настоящего фона.
    """
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
    """Заливка от краёв по отрезкам строк.

    Обычная заливка попиксельно на полутора миллионах точек в Python стоит
    десятки секунд; здесь за раз берётся целый горизонтальный отрезок, и
    работы остаётся на тысячи шагов вместо миллионов.
    """
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
    """Что здесь рисунок, а что фон.

    Готовая альфа берётся как есть — художник уже ответил на этот вопрос.
    Там, где её нет, фон ищется заливкой от краёв, а не порогом по цвету:
    порог объявляет фоном всё, что похоже на фоновый цвет, включая белую
    рубашку на белом листе. Заливка же считает фоном только то, до чего
    можно дойти снаружи, не пересекая рисунок.
    """
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
    """Середина туловища по горизонтали.

    Берётся полоса между плечами и бёдрами: она не участвует ни в махе рук,
    ни в выносе ноги, поэтому её центр стоит на месте весь цикл ходьбы.
    """
    height = bottom - top + 1
    band_top = top + int(height * TORSO_BAND[0])
    band_bottom = top + int(height * TORSO_BAND[1])
    band = mask[band_top:band_bottom + 1]
    columns = np.where(band.any(axis=0))[0]
    if columns.size == 0:
        raise SystemExit("не найдено туловище: кадр обрезан или пустой")
    return float(columns[0] + columns[-1]) / 2.0


def resample(image: np.ndarray, mask: np.ndarray, scale: float) -> tuple[np.ndarray, np.ndarray]:
    """Ужать выборкой ближайшего пикселя.

    Без сглаживания: у пиксель-арта интерполяция размывает те самые края,
    ради которых он рисуется. Сетка в исходнике уже размыта пересохранением,
    и добавлять к этому ещё один размыв незачем.
    """
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

    # Смещение считается по опорам, а не по рамке: рамка гуляет вместе
    # с руками и ногами, опоры стоят на месте.
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

        # Крошку по контуру счищать нужно только там, где силуэт вырезан из
        # фона: у кадра с готовой альфой края чистые по определению, и
        # чистка тронула бы уже сам рисунок.
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
