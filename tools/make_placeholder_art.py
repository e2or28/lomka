#!/usr/bin/env python3
"""Заглушки для спрайтов, которых ещё нет.

Это НЕ арт. Арт остаётся человеку — так записано в docs/PLAN.md, и код его
не заменит. Здесь ровно то, без чего нельзя проверить бой: узнаваемые формы
в палитре персонажа, чтобы на экране было видно, кто в кого кинул.

Почему кодом, а не картинкой в репозитории. Заглушку положено выбросить,
когда придёт настоящий спрайт, и до тех пор её надо уметь править: сменить
размер, подвинуть глаз, перекрасить. Пиксельная карта строками правится за
секунды и читается в диффе, а PNG в гите — это непрозрачный бинарник,
который никто не тронет.

    python3 tools/make_placeholder_art.py [--out art]
"""

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

# Палитра снята с персонажа: обводка и тени те же, чтобы заглушки не
# выбивались из кадра, пока настоящих спрайтов нет.
PALETTE = {
    ".": (0, 0, 0, 0),
    "#": (0x2C, 0x2E, 0x33, 255),   # обводка, она же у персонажа
    "o": (0x44, 0x47, 0x4E, 255),   # мягкая тень
    "Y": (0xC9, 0xA2, 0x55, 255),   # папка, светлое
    "y": (0xA8, 0x84, 0x40, 255),   # папка, тень
    "W": (0xE8, 0xE4, 0xD8, 255),   # бумага
    "w": (0xC2, 0xBE, 0xB2, 255),   # бумага в тени
    "M": (0x6E, 0x7A, 0x55, 255),   # монстр, светлое
    "m": (0x4C, 0x56, 0x3B, 255),   # монстр, тень
    "R": (0x9A, 0x3B, 0x3B, 255),   # пасть
    "E": (0xE8, 0xE4, 0xD8, 255),   # белок глаза
    "P": (0x2C, 0x2E, 0x33, 255),   # зрачок
}

# Папка с документами: снаряд служащего. Летит уголком вперёд, из неё
# торчат листы — на скорости читается именно по ним.
FOLDER = """
....#####....
...#WWWWW#...
..#WwwwwwW#..
.#WwwwwwwwW#.
#YYYYYYYYYYY#
#YyyyyyyyyyY#
#YyYYYYYYyyY#
#YyYYYYYYyyY#
#YyyyyyyyyyY#
#YYYYYYYYYYY#
.#yyyyyyyyy#.
..#########..
"""

# Монстр: заглушка под манекен из комнаты разработчиков. Приземистый силуэт
# с крупными глазами — читается на своём размере и не притворяется дизайном.
MONSTER = """
......#######......
....##ooooooo##....
...#ooMMMMMMMoo#...
..#oMMMMMMMMMMMo#..
.#oMMMMMMMMMMMMMo#.
.#MMMMMMMMMMMMMMM#.
#MM##EEE#MM#EEE##MM#
#MM#EEPEE#M#EEPEE#MM
#MM#EEPEE#M#EEPEE#MM
#MM##EEE#MM#EEE##MM#
.#MMMMMMMMMMMMMMM#.
.#MMMM#######MMMM#.
.#MMM#RRRRRRR#MMM#.
.#MMM#R#R#R#R#MMM#.
.#MMM#RRRRRRR#MMM#.
.#MMMM#######MMMM#.
.#mMMMMMMMMMMMMMm#.
..#mmMMMMMMMMMmm#..
...#mmmmmmmmmmm#...
....#####mm####....
.....#mm#.#mm#.....
.....####.####.....
"""


def parse(art: str) -> np.ndarray:
    rows = [line for line in art.strip("\n").split("\n") if line]
    width = max(len(row) for row in rows)
    canvas = np.zeros((len(rows), width, 4), dtype=np.uint8)
    for y, row in enumerate(rows):
        for x, symbol in enumerate(row):
            if symbol not in PALETTE:
                raise SystemExit(f"неизвестный символ '{symbol}' в строке {y + 1}")
            canvas[y, x] = PALETTE[symbol]
    return canvas


def scale(sprite: np.ndarray, factor: int) -> np.ndarray:
    """Увеличение повтором пикселя. Карты рисуются мелкими, чтобы их можно
    было держать в голове, а в игру идут в масштабе персонажа."""
    return np.repeat(np.repeat(sprite, factor, axis=0), factor, axis=1)


def write(sprite: np.ndarray, path: Path) -> None:
    height, width = sprite.shape[:2]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{width}x{height}", "-i", "-", "-y", str(path)],
        input=sprite.tobytes(), check=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path("art"))
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    # Масштабы подобраны под персонажа: он 58x159, монстр заметно ниже,
    # папка размером с ладонь.
    plan = [("folder", FOLDER, 2), ("monster", MONSTER, 4)]
    for name, art, factor in plan:
        sprite = scale(parse(art), factor)
        target = args.out / f"{name}.png"
        write(sprite, target)
        print(f"  {target}  {sprite.shape[1]}x{sprite.shape[0]}")

    print("\nЭто заглушки. Положи настоящий PNG с тем же именем — он их перекроет.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
