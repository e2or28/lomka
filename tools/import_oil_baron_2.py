#!/usr/bin/env python3
"""Импорт партии Саши от 10 сентября; исходники сохраняются рядом с игрой."""
from pathlib import Path

import numpy as np

from import_sprite import decode_rgba, encode, resize_to_height

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/oil_baron_2_source"
BARON_SOURCE = ROOT / "art/oil_baron_source/3c7b93b3-863d-4147-ace2-d5f4182b1f2e.png"

# Охрана этой партии стреляет с колена, и рост тут больше не мера: боец на
# колене ниже стоящего на треть, а нормировка по росту сделала бы из него
# великана вровень со стоящим. Мерой служит головной убор — он один и тот же
# в любой позе. Числа сняты с кадров 9 сентября: каска на soldier*.png и
# расстояние от полей сомбреро до пола на тогдашних ice_agent*.png, которые
# этот же импортёр теперь перезаписывает.
HELMET = 43.0
SOMBRERO_DROP = 146.0

GUARDS = {
    "soldier_fire": "солдат_сбоку_на_колене_стреляет(1).png",
    "soldier_fire_front": "солдат_спереди_на_колене_стреляет(1).png",
    "soldier_dark_fire": "солдат_сбоку_стреляет_прозрачный(1).png",
    "soldier_dark_fire_front": "солдат_спереди_стреляет_прозрачный(1).png",
    "soldier_dark_kneel": "черный солдат_сбоку_оружие_опущено(1).png",
    "soldier_dark_kneel_front": "чёрный солдат_спереди_оружие_опущено(1).png",
}

# ICE перерисован заново и заменяет кадры 9 сентября — те остались только
# исходниками, и их больше не воспроизводит import_oil_baron.py.
ICE = {
    "ice_agent": "ice_idle.png",
    "ice_agent_front": "ice_idle_front.png",
    "ice_agent_windup": "ice_attack_side.png",
    "ice_agent_windup_front": "ice_attack_front.png",
}

BARON = {
    "oil_baron_call": "барон вызвал подкрепление.png",
    "oil_baron_down": "барон побеждён.png",
}


def silhouette(path: Path):
    rgb, alpha = decode_rgba(path)
    return rgb, alpha > 128


def row_spans(mask, top, bottom):
    """Ширина силуэта построчно: у пустой строки ноль."""
    spans = []
    for row in mask[top:bottom]:
        xs = np.where(row)[0]
        spans.append((xs[0], xs[-1]) if xs.size else None)
    return spans


def headwear(mask, brim_threshold=0.0):
    """Ширина и центр головного убора плюс его верхняя строка.

    Верхние строки силуэта — не всегда голова: у замаха над ней дубинка.
    Поэтому поля ищутся как первая строка, которая шире доли от всего
    силуэта; для каски порог нулевой, и полосой становится сама макушка.
    """
    ys, xs = np.where(mask)
    top, bottom = int(ys.min()), int(ys.max())
    width = int(xs.max() - xs.min() + 1)
    spans = row_spans(mask, top, bottom + 1)
    brim = 0
    if brim_threshold:
        for i, span in enumerate(spans):
            if span is not None and span[1] - span[0] + 1 > width * brim_threshold:
                brim = i
                break
    band = spans[brim:brim + max(int((bottom - top + 1) * 0.15), 1)]
    solid = [s for s in band if s is not None]
    size = max(s[1] - s[0] + 1 for s in solid)
    center = float(np.mean([(s[0] + s[1]) / 2 for s in solid]))
    return size, center, top + brim, bottom


def place(rgb, mask, scale, center_x, bottom, name):
    """Кадр в холст 160×200 с опорой (80,194), выборкой ближайшего пикселя."""
    out = np.zeros((200, 160, 4), dtype=np.uint8)
    oy, ox = np.indices(out.shape[:2])
    sy = np.rint(bottom + (oy - 194) / scale).astype(int)
    sx = np.rint(center_x + (ox - 80) / scale).astype(int)
    height, width = mask.shape
    valid = (sy >= 0) & (sy < height) & (sx >= 0) & (sx < width)
    out[valid, :3] = rgb[sy[valid], sx[valid]]
    out[valid, 3] = np.where(mask[sy[valid], sx[valid]], 255, 0)
    # Выборка может промахнуться мимо подошвы шириной в один исходный
    # пиксель, и боец повисает над полом. Опора восстанавливается уже на
    # готовом кадре — так же, как в импортёре партии 9 сентября.
    shift = 194 - int(np.where(out[:, :, 3] > 0)[0].max())
    if shift > 0:
        out[shift:] = out[:-shift].copy()
        out[:shift] = 0
    encode(out, ROOT / f"art/{name}.png")
    drawn = np.where(out[:, :, 3] > 0)[0]
    print(f"{name}: 160×200, опора (80,194), высота силуэта {drawn.max() - drawn.min() + 1}")


def main():
    for name, filename in GUARDS.items():
        rgb, mask = silhouette(SOURCE / filename)
        size, center, _, bottom = headwear(mask)
        place(rgb, mask, HELMET / size, center, bottom, name)

    for name, filename in ICE.items():
        rgb, mask = silhouette(SOURCE / filename)
        _, center, brim, bottom = headwear(mask, brim_threshold=0.35)
        place(rgb, mask, SOMBRERO_DROP / (bottom - brim), center, bottom, name)

    # Фазы барона режутся по рамке исходной качалки, а не по своей: у
    # поверженного станок осел, и обрезка по собственному силуэту подняла бы
    # обломки на место целого механизма.
    _, base = silhouette(BARON_SOURCE)
    ys, xs = np.where(base)
    for name, filename in BARON.items():
        rgb, mask = silhouette(SOURCE / filename)
        frame = np.dstack((rgb, np.where(mask, 255, 0)))
        frame = frame[ys.min():ys.max() + 1, xs.min():xs.max() + 1]
        frame = resize_to_height(frame.astype(np.uint8), 330)
        encode(frame, ROOT / f"art/{name}.png")
        print(f"{name}: {frame.shape[1]}×330, рамка общая с oil_baron.png")


if __name__ == "__main__":
    main()
