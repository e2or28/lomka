#!/usr/bin/env python3
"""Нарисованная комната -> фон под игровую зону.

Зачем отдельно от спрайтов. У спрайта важен сам рисунок, и его достаточно
привести к нативному размеру. У комнаты важно не это, а совпадение: пол на
картинке обязан лечь ровно на ту прямоугольную область, внутри которой
симуляция держит тела (Room.bounds). Разъедется на десяток пикселей — и
персонаж будет упираться в невидимую стену, стоя посреди нарисованного
пола, либо заходить ногами в нарисованную стену.

Поэтому вход у инструмента не только картинка, но и рамка пола на ней. Она
задаётся руками и не угадывается кодом: на этих комнатах граница пола и
стены размыта тенью, а текстура ковра и обоев одинаково зерниста —
автоопределение здесь врёт молча, а врать оно будет ровно в том, что
проверяется руками и долго.

    tools/import_room.py ВХОД ВЫХОД --inner X0,Y0,X1,Y1 [--room 1160x640]

  --inner   рамка пола на исходнике, включительно, в пикселях
  --room    размер игровой зоны, куда её сажать (по умолчанию dev_room)
  --fit     stretch (по умолчанию) — пол ровно в игровую зону;
            width — сохранить пропорции картинки, подогнав по ширине

Про stretch. Пол этих комнат нарисован в пропорции около 1.69, а игровая
зона — 1.81; разница в семь процентов уезжает в вертикальное сжатие. Это
осознанный выбор в пользу совпадения границ: на гладком фоне сжатие не
читается вовсе, а несовпадение стены с невидимой границей читается сразу
и мешает играть. Режим width оставлен на случай, когда художник нарисует
комнату в правильной пропорции — тогда сжимать будет нечего.

Инструмент печатает отступ стен: сколько пикселей нарисовано слева и сверху
от игровой зоны. Это число нужно представлению, чтобы положить фон, и его
надо перенести в WorldView.ROOM_INSET.
"""

import argparse
import subprocess
import sys
from pathlib import Path


def probe(path: Path) -> tuple[int, int]:
    result = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries",
         "stream=width,height", "-of", "csv=p=0:s=x", str(path)],
        capture_output=True, text=True, check=True)
    width, height = (int(v) for v in result.stdout.strip().split("x"))
    return width, height


def main() -> int:
    parser = argparse.ArgumentParser(
        description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("source", type=Path)
    parser.add_argument("target", type=Path)
    parser.add_argument("--inner", required=True,
                        help="рамка пола на исходнике: X0,Y0,X1,Y1")
    parser.add_argument("--room", default="1160x640")
    parser.add_argument("--fit", choices=("stretch", "width"), default="stretch")
    args = parser.parse_args()

    if not args.source.exists():
        print(f"нет файла: {args.source}", file=sys.stderr)
        return 1

    x0, y0, x1, y1 = (int(v) for v in args.inner.split(","))
    room_w, room_h = (int(v) for v in args.room.lower().split("x"))
    inner_w, inner_h = x1 - x0 + 1, y1 - y0 + 1
    if inner_w <= 0 or inner_h <= 0:
        print("рамка пола вывернута наизнанку", file=sys.stderr)
        return 1

    width, height = probe(args.source)
    scale_x = room_w / inner_w
    scale_y = room_h / inner_h if args.fit == "stretch" else scale_x

    out_w = round(width * scale_x)
    out_h = round(height * scale_y)
    inset_x = round(x0 * scale_x)
    inset_y = round(y0 * scale_y)

    args.target.parent.mkdir(parents=True, exist_ok=True)
    subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(args.source),
         "-vf", f"scale={out_w}:{out_h}:flags=lanczos", "-y", str(args.target)],
        check=True)

    print(f"{args.source.name}  {width}x{height}")
    print(f"  пол на исходнике: {inner_w}x{inner_h} @ {x0},{y0}"
          f"  (пропорция {inner_w / inner_h:.3f})")
    print(f"  игровая зона:     {room_w}x{room_h}  (пропорция {room_w / room_h:.3f})")
    print(f"  масштаб:          {scale_x:.4f} по ширине, {scale_y:.4f} по высоте")
    print(f"  записано:         {args.target}  {out_w}x{out_h}")
    print(f"  ОТСТУП СТЕН:      Vector2({inset_x}, {inset_y})  -> WorldView.ROOM_INSET")
    if out_w - inset_x - room_w < 0 or out_h - inset_y - room_h < 0:
        print("  ВНИМАНИЕ: рамка пола выходит за картинку — проверь --inner")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
