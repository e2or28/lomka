# Метательная папка Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Создать прозрачный нативный PNG переполненной метательной папки в пиксельной стилистике служащего.

**Architecture:** Встроенный генератор создаёт исходник с `art/player.png` как стилевым референсом. Результат проверяется визуально, затем приводится к нативному игровому размеру и сохраняется рядом с заглушкой под новым именем, не заменяя `art/folder.png`.

**Tech Stack:** встроенный `image_gen`, PNG с alpha, существующий `tools/import_sprite.py`, Godot art hot-reload.

---

### Task 1: Сгенерировать исходник папки

**Files:**
- Reference: `art/player.png`
- Create: встроенный исходный PNG генератора

- [x] **Step 1: Сгенерировать один изолированный объект**

Передать `art/player.png` как стилевой референс и запросить переполненную охристую папку с кремовыми листами, бордовыми завязками, тёмным пиксельным контуром и прозрачным фоном.

- [x] **Step 2: Проверить исходник визуально**

Убедиться, что папка читается как единый компактный снаряд, не содержит текста, фона, тени, движения или посторонних объектов.

### Task 2: Подготовить проектный PNG

**Files:**
- Create: `art/folder-overstuffed-v1.png`
- Preserve: `art/folder.png`

- [x] **Step 1: Привести исходник к нативному размеру**

Run:

```bash
python3 tools/import_sprite.py <generated-source.png> art/folder-overstuffed-v1.png --height 28
```

Expected: прозрачный PNG высотой около 28 пикселей с сохранённым читаемым силуэтом.

- [x] **Step 2: Проверить формат и альфа-канал**

Run:

```bash
file art/folder-overstuffed-v1.png
sips -g pixelWidth -g pixelHeight art/folder-overstuffed-v1.png
```

Expected: RGBA PNG, высота около 28 пикселей, ширина достаточна для горизонтальной папки.

- [x] **Step 3: Сравнить с персонажем визуально**

Открыть `art/folder-overstuffed-v1.png` и проверить палитру, размер пикселя, контур и читаемость на масштабе 1:1.

- [x] **Step 4: Зафиксировать результат**

```bash
git add docs/superpowers/plans/2026-09-02-document-folder-asset.md art/folder-overstuffed-v1.png
git commit -m "Метательная папка: первый пиксельный вариант"
```
