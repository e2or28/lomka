#!/usr/bin/env python3
"""Апскейленная картинка -> игровой спрайт в нативном разрешении.

Зачем. Генераторы и чаты отдают пиксель-арт растянутым: холст 1024x1536,
внутри которого настоящий рисунок вроде 52x142. Положить такой файл в игру
нельзя — он займёт пол-экрана и будет мылиться. Ужать его в редакторе
вручную тоже нельзя: любая интерполяция размажет края, ради которых пиксель-
арт и рисуется.

Инструмент делает три вещи: находит шаг сетки апскейла, берёт по одному
цвету на ячейку (медианой, а не усреднением — усреднение мылит), и вырезает
фон в прозрачность.

Зависимостей нет, кроме ffmpeg и numpy: оба уже стоят. Pillow на этой машине
не ставится, системный Python защищён PEP 668, и ломать его ради одной
задачи не стоит.

    tools/import_sprite.py ВХОД ВЫХОД [--height N] [--step S] [--keep-bg]

  --height N   ужать до N пикселей высотой (после обрезки полей)
  --step S     задать шаг сетки вручную, если автоопределение промахнулось
  --keep-bg    не вырезать фон
  --no-trim    не обрезать поля, оставить весь холст

Для кадров анимации обрезать поля нельзя: каждый кадр обрежется по-своему,
и персонаж запрыгает. Кадры импортируются с --no-trim, а общая рамка
подбирается по всем кадрам сразу — этим занимается tools/import_frames.py.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

# Насколько цвет должен отличаться от фонового, чтобы считаться рисунком.
# JPEG шумит на ровных заливках, поэтому порог не нулевой.
BACKGROUND_TOLERANCE = 40

# В каких пределах искать шаг сетки апскейла.
STEP_RANGE = (3.0, 40.0)


def decode(path: Path) -> np.ndarray:
    """Картинка -> массив (h, w, 3). Через ffmpeg, чтобы не тянуть Pillow."""
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True)
    width, height = (int(v) for v in probe.stdout.strip().split("x"))

    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
         "-pix_fmt", "rgb24", "-"],
        capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 3)


def encode(pixels: np.ndarray, path: Path) -> None:
    """Массив (h, w, 4) -> PNG."""
    height, width = pixels.shape[:2]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{width}x{height}", "-i", "-", "-y", str(path)],
        input=pixels.astype(np.uint8).tobytes(), check=True)


def detect_step(image: np.ndarray, mask: np.ndarray) -> float:
    """Шаг сетки апскейла.

    Ищется по расстояниям между границами цвета: у растянутого пиксель-арта
    они кратны размеру ячейки. Берётся медиана расстояний, отбросив единицы
    и двойки — это шум сжатия на градиентах, а не границы рисунка.
    """
    gaps = []
    height, width = mask.shape
    rows = np.where(mask.any(axis=1))[0]
    columns = np.where(mask.any(axis=0))[0]
    if rows.size == 0 or columns.size == 0:
        raise SystemExit("на картинке не найдено ничего, кроме фона")

    for y in range(rows[0], rows[-1], max((rows[-1] - rows[0]) // 60, 1)):
        line = image[y, columns[0]:columns[-1] + 1].astype(np.int16)
        jumps = np.where(np.abs(np.diff(line, axis=0)).sum(axis=1) > 28)[0]
        gaps.extend(np.diff(jumps).tolist())
    for x in range(columns[0], columns[-1], max((columns[-1] - columns[0]) // 60, 1)):
        line = image[rows[0]:rows[-1] + 1, x].astype(np.int16)
        jumps = np.where(np.abs(np.diff(line, axis=0)).sum(axis=1) > 28)[0]
        gaps.extend(np.diff(jumps).tolist())

    useful = [g for g in gaps if STEP_RANGE[0] <= g <= STEP_RANGE[1]]
    if not useful:
        raise SystemExit("не удалось определить шаг сетки — задай его через --step")
    return float(np.median(useful))


def decode_rgba(path: Path) -> tuple[np.ndarray, np.ndarray]:
    """Картинка -> (rgb, alpha). Альфа читается всегда, даже когда её нет:
    у непрозрачного PNG она приедет сплошными единицами и ничего не испортит.

    Читать без альфы нельзя. Прозрачный пиксель, прочитанный как rgb,
    становится чёрным, фоном объявляется чёрный — и вместе с фоном из
    спрайта вырезается всё тёмное, что в нём нарисовано.
    """
    probe = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0",
         "-show_entries", "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True)
    width, height = (int(v) for v in probe.stdout.strip().split("x"))

    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "rawvideo",
         "-pix_fmt", "rgba", "-"],
        capture_output=True, check=True).stdout
    pixels = np.frombuffer(raw, dtype=np.uint8).reshape(height, width, 4)
    return pixels[:, :, :3], pixels[:, :, 3]


def has_alpha(alpha: np.ndarray) -> bool:
    """Осмысленная ли прозрачность, или канал формальный."""
    return bool((alpha < 50).mean() > 0.01)


def content_mask(image: np.ndarray, alpha: np.ndarray = None) -> np.ndarray:
    """Что здесь рисунок, а что фон.

    Готовая альфа берётся как есть: художник уже ответил на этот вопрос,
    и угадывать поверх его ответа незачем. Без неё фоном считается цвет
    левого верхнего угла.
    """
    if alpha is not None and has_alpha(alpha):
        return alpha > 128
    background = image[0, 0].astype(np.int16)
    distance = np.abs(image.astype(np.int16) - background).sum(axis=2)
    return distance > BACKGROUND_TOLERANCE


def downsample(image: np.ndarray, mask: np.ndarray, step: float,
               whole_canvas: bool = False) -> np.ndarray:
    """Одна ячейка сетки -> один пиксель. Медиана центра, а не среднее по
    ячейке: среднее смешивает цвета на границах и даёт кайму.

    whole_canvas берёт весь холст, а не рамку содержимого: для кадров
    анимации важно, чтобы у всех кадров была общая система координат.
    """
    if whole_canvas:
        top, left = 0, 0
        bottom, right = image.shape[0], image.shape[1]
    else:
        rows = np.where(mask.any(axis=1))[0]
        columns = np.where(mask.any(axis=0))[0]
        top, bottom = int(rows[0]), int(rows[-1]) + 1
        left, right = int(columns[0]), int(columns[-1]) + 1

    out_h = max(int(round((bottom - top) / step)), 1)
    out_w = max(int(round((right - left) / step)), 1)
    result = np.zeros((out_h, out_w, 4), dtype=np.uint8)

    for y in range(out_h):
        for x in range(out_w):
            y0 = top + (bottom - top) * y // out_h
            y1 = max(top + (bottom - top) * (y + 1) // out_h, y0 + 1)
            x0 = left + (right - left) * x // out_w
            x1 = max(left + (right - left) * (x + 1) // out_w, x0 + 1)

            # Центр ячейки: края съедены интерполяцией апскейла и JPEG
            cy0, cy1 = y0 + (y1 - y0) // 4, y1 - (y1 - y0) // 4
            cx0, cx1 = x0 + (x1 - x0) // 4, x1 - (x1 - x0) // 4
            patch = image[max(cy0, y0):max(cy1, cy0 + 1), max(cx0, x0):max(cx1, cx0 + 1)]
            cover = mask[y0:y1, x0:x1]

            result[y, x, :3] = np.median(patch.reshape(-1, 3), axis=0)
            result[y, x, 3] = 255 if cover.mean() > 0.5 else 0
    return result


def despeckle(sprite: np.ndarray, background: np.ndarray) -> np.ndarray:
    """Убрать крошку фона по контуру.

    JPEG размывает границу рисунка с фоном, и после ужатия по краю силуэта
    остаются одиночные пиксели почти фонового цвета. На светлом фоне это
    белая пыль на плечах и волосах.

    Осторожно: убираются только пиксели, которые и близки к фону, и стоят на
    самом краю. Иначе вместе с крошкой уйдут блики, которые художник
    поставил намеренно.
    """
    result = sprite.copy()
    alpha = sprite[:, :, 3]
    height, width = alpha.shape
    padded = np.zeros((height + 2, width + 2), dtype=bool)
    padded[1:-1, 1:-1] = alpha > 0

    for y in range(height):
        for x in range(width):
            if alpha[y, x] == 0:
                continue
            neighbours = padded[y:y + 3, x:x + 3]
            if neighbours.sum() - 1 >= 7:
                continue  # окружён рисунком — это не край
            if np.abs(sprite[y, x, :3].astype(np.int16) - background).sum() < 60:
                result[y, x, 3] = 0
    return result


def resize_to_height(sprite: np.ndarray, height: int) -> np.ndarray:
    """Ужать выборкой ближайшего пикселя. Никакого сглаживания: в пиксель-арте
    оно превращает силуэт в кашу."""
    src_h, src_w = sprite.shape[:2]
    width = max(int(round(src_w * height / src_h)), 1)
    ys = (np.arange(height) * src_h // height).clip(0, src_h - 1)
    xs = (np.arange(width) * src_w // width).clip(0, src_w - 1)
    return sprite[ys][:, xs]


def trim(sprite: np.ndarray) -> np.ndarray:
    """Обрезать полностью прозрачные поля."""
    solid = sprite[:, :, 3] > 0
    if not solid.any():
        return sprite
    rows = np.where(solid.any(axis=1))[0]
    columns = np.where(solid.any(axis=0))[0]
    return sprite[rows[0]:rows[-1] + 1, columns[0]:columns[-1] + 1]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--height", type=int, default=0)
    parser.add_argument("--step", type=float, default=0.0)
    parser.add_argument("--keep-bg", action="store_true")
    parser.add_argument("--no-trim", action="store_true")
    args = parser.parse_args()

    if not args.source.exists():
        print(f"нет файла: {args.source}", file=sys.stderr)
        return 1

    image, alpha = decode_rgba(args.source)
    mask = content_mask(image, alpha)
    step = args.step or detect_step(image, mask)

    sprite = downsample(image, mask, step, whole_canvas=args.no_trim)
    if args.keep_bg:
        sprite[:, :, 3] = 255
    elif not has_alpha(alpha):
        # Крошку по контуру счищать нужно только там, где силуэт вырезан
        # из фона: у спрайта с готовой альфой края чистые по определению.
        sprite = despeckle(sprite, image[0, 0].astype(np.int16))
    if not args.no_trim:
        sprite = trim(sprite)

    detected = f"{sprite.shape[1]}x{sprite.shape[0]}"
    if args.height:
        sprite = resize_to_height(sprite, args.height)

    args.target.parent.mkdir(parents=True, exist_ok=True)
    encode(sprite, args.target)

    print(f"{args.source.name}  {image.shape[1]}x{image.shape[0]}")
    print(f"  шаг сетки:  {step:.2f} px")
    print(f"  распознано: {detected}")
    print(f"  записано:   {args.target}  {sprite.shape[1]}x{sprite.shape[0]}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
