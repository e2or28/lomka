#!/usr/bin/env python3
"""Заглушки для спрайтов, которых ещё нет. Это не арт — арт остаётся
человеку, здесь только узнаваемые формы, чтобы можно было проверить бой.

Пиксельная карта строками, а не PNG: правится за секунды и читается в
диффе.

    python3 tools/make_placeholder_art.py [--out art] [--force]

Существующие файлы не трогает: однажды перезаписал утверждённый портфель
своей картинкой, поймал это только тест на размер. --force осознанно.
"""

import argparse
import subprocess
import sys
from pathlib import Path

import numpy as np

PALETTE = {
    ".": (0, 0, 0, 0),
    "#": (0x2C, 0x2E, 0x33, 255),   # обводка, она же у персонажа
    "o": (0x44, 0x47, 0x4E, 255),   # мягкая тень
    "Y": (0xC9, 0xA2, 0x55, 255),   # папка, светлое
    "y": (0xA8, 0x84, 0x40, 255),   # папка, тень
    "W": (0xE8, 0xE4, 0xD8, 255),   # бумага
    "w": (0xC2, 0xBE, 0xB2, 255),   # бумага в тени
    "B": (0x6B, 0x4A, 0x2E, 255),   # чемодан, кожа
    "b": (0x4E, 0x35, 0x20, 255),   # чемодан, тень
    "L": (0xC9, 0xA2, 0x55, 255),   # замки и ручка
    "M": (0x6E, 0x7A, 0x55, 255),   # монстр, светлое
    "m": (0x4C, 0x56, 0x3B, 255),   # монстр, тень
    "R": (0x9A, 0x3B, 0x3B, 255),   # пасть
    "E": (0xE8, 0xE4, 0xD8, 255),   # белок глаза
    "P": (0x2C, 0x2E, 0x33, 255),   # зрачок
}

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
    return np.repeat(np.repeat(sprite, factor, axis=0), factor, axis=1)


def write(sprite: np.ndarray, path: Path) -> None:
    height, width = sprite.shape[:2]
    subprocess.run(
        ["ffmpeg", "-v", "error", "-f", "rawvideo", "-pix_fmt", "rgba",
         "-s", f"{width}x{height}", "-i", "-", "-y", str(path)],
        input=sprite.tobytes(), check=True)


SUITCASE = """
.....LLL.....
....L...L....
#############
#BBBBBBBBBBB#
#BBLBBBBBLBB#
#BbbbbbbbbbB#
#BBBBBBBBBBB#
#bbbbbbbbbbb#
#############
"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--out", type=Path, default=Path("art"))
    parser.add_argument("--force", action="store_true",
                        help="перезаписать существующие файлы")
    args = parser.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)

    plan = [("folder", FOLDER, 2), ("monster", MONSTER, 4), ("suitcase", SUITCASE, 2)]
    written = 0
    for name, art, factor in plan:
        target = args.out / f"{name}.png"
        if target.exists() and not args.force:
            print(f"  {target}  уже есть, не трогаю")
            continue
        sprite = scale(parse(art), factor)
        write(sprite, target)
        written += 1
        print(f"  {target}  {sprite.shape[1]}x{sprite.shape[0]}")

    if written == 0:
        print("\nВсё на месте. Перезаписать заглушками: --force")
        return 0

    print("\nЭто заглушки. Положи настоящий PNG с тем же именем — он их перекроет.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
