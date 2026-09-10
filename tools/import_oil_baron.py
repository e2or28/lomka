#!/usr/bin/env python3
"""Импорт партии Саши от 9 сентября; исходники сохраняются рядом с игрой."""
from pathlib import Path

import numpy as np

from import_sprite import decode_rgba, encode, resize_to_height, trim

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "art/oil_baron_source"
# Верх сомбреро замерен отдельно: поднятая дубинка не уменьшает тело.
FRAMES = {
    "soldier": ("af8c76aa-5075-4358-a9cd-5abafbd411d3.png", 0),
    "soldier_front": ("01137e46-714d-4bb4-a9d3-7c59b696580a.png", 0),
    "soldier_dark": ("be728592-a995-4643-854f-9a0bdcc9ba10.png", 0),
    "soldier_dark_front": ("c37bde92-f3a1-42e1-a678-69dbc27daa52.png", 0),
    "ice_agent": ("ice_agent_sombrero_side_godot.png", 0),
    "ice_agent_front": ("ice_agent_sombrero_godot_cropped.png", 0),
    "ice_agent_windup": ("ice_agent_sombrero_windup_side_godot.png", 155),
    "ice_agent_windup_front": ("ice_agent_sombrero_windup_front_godot.png", 198),
}


def main():
    for name, (filename, head_top) in FRAMES.items():
        rgb, alpha = decode_rgba(SOURCE / filename)
        mask = alpha > 128
        ys, xs = np.where(mask)
        top, bottom = int(ys.min()), int(ys.max())
        scale = 156 / (bottom - max(top, head_top) + 1)
        feet = np.where(mask[int(bottom - 0.15 * (bottom - top)):bottom + 1].any(axis=0))[0]
        center = (feet[0] + feet[-1]) / 2
        height, width = mask.shape
        out = np.zeros((200, 160, 4), dtype=np.uint8)
        oy, ox = np.indices(out.shape[:2])
        sy = np.rint(bottom + (oy - 194) / scale).astype(int)
        sx = np.rint(center + (ox - 80) / scale).astype(int)
        valid = (sy >= 0) & (sy < height) & (sx >= 0) & (sx < width)
        out[valid, :3] = rgb[sy[valid], sx[valid]]
        out[valid, 3] = np.where(mask[sy[valid], sx[valid]], 255, 0)
        # Выборка может пропустить самый край подошвы шириной в один
        # исходный пиксель. Опору восстанавливаем уже на готовом кадре.
        shift = 194 - int(np.where(out[:, :, 3] > 0)[0].max())
        if shift > 0:
            out[shift:] = out[:-shift].copy()
            out[:shift] = 0
        encode(out, ROOT / f"art/{name}.png")
        print(f"{name}: 160×200, опора (80,194)")
    rgb, alpha = decode_rgba(SOURCE / "3c7b93b3-863d-4147-ace2-d5f4182b1f2e.png")
    boss = np.dstack((rgb, np.where(alpha > 128, 255, 0))).astype(np.uint8)
    boss = resize_to_height(trim(boss), 330)
    encode(boss, ROOT / "art/oil_baron.png")
    print(f"oil_baron: {boss.shape[1]}×330")


if __name__ == "__main__":
    main()
