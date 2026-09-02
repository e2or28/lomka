# Briefcase Flight Animation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Заменить заглушку снаряда финальным чёрным A4-портфелем и отрисовать один параболический прыжок с одним полным переворотом за полёт.

**Architecture:** Симуляция, столкновения и сохранение не меняются. Чистый модуль `ProjectilePose` переводит нормализованный прогресс полёта в высоту, угол и параметры тени; `WorldView` хранит только локальный возраст и начальную длительность видимых снарядов.

**Tech Stack:** Godot 4.7.2/GDScript, CanvasItem drawing, headless test harness, PNG/alpha pipeline.

---

### Task 1: Математика прыжка и переворота

**Files:**
- Create: `game/projectile_pose.gd`
- Create: `tests/test_projectile_pose.gd`
- Modify: `tests/README.md`

- [x] **Step 1: Написать тест до реализации**

Тест должен потребовать API `progress(age, duration)`, `lift(progress)`, `rotation(progress)`, `shadow_scale(progress)` и `shadow_alpha(progress)`. Проверить зажим прогресса, нулевую высоту в начале и конце, высоту `JUMP_HEIGHT` в середине и угол от `0` до ровно `TAU` без второго оборота.

- [x] **Step 2: Запустить тест и увидеть правильное падение**

Run:

```bash
tools/test.sh
```

Expected: FAIL/ошибка загрузки `res://game/projectile_pose.gd`, потому что модуль ещё не существует.

- [x] **Step 3: Реализовать минимальный чистый модуль**

```gdscript
extends RefCounted

const JUMP_HEIGHT := 22.0
const SHADOW_MIN_SCALE := 0.68
const SHADOW_GROUND_ALPHA := 0.30
const SHADOW_AIR_ALPHA := 0.14

static func progress(age: float, duration: float) -> float:
    if duration <= 0.0:
        return 1.0
    return clampf(age / duration, 0.0, 1.0)

static func lift(value: float) -> float:
    return sin(clampf(value, 0.0, 1.0) * PI) * JUMP_HEIGHT

static func rotation(value: float) -> float:
    return clampf(value, 0.0, 1.0) * TAU

static func shadow_scale(value: float) -> float:
    return lerpf(1.0, SHADOW_MIN_SCALE, sin(clampf(value, 0.0, 1.0) * PI))

static func shadow_alpha(value: float) -> float:
    return lerpf(SHADOW_GROUND_ALPHA, SHADOW_AIR_ALPHA, sin(clampf(value, 0.0, 1.0) * PI))
```

- [x] **Step 4: Запустить тесты и получить зелёный результат**

Run: `tools/test.sh`

Expected: новый файл `поза снаряда` проходит; старые проверки не регрессируют.

### Task 2: Финальный PNG как реальный снаряд

**Files:**
- Modify: `tests/test_art_library.gd`
- Replace: `art/folder.png`
- Delete: `art/folder_briefcase_black.png`
- Modify: `art/README.md`

- [x] **Step 1: Добавить проверку реального ассета**

Проверить загрузку `res://art/folder.png`, ширину `42`, высоту `34` и наличие альфа-канала. Одновременно заменить ошибочные ожидания `Vector2i` для `Texture2D.get_size()` на `Vector2`, чтобы тестовый вывод не содержал runtime-error.

- [x] **Step 2: Запустить тест и увидеть падение на заглушке 26×24**

Run: `tools/test.sh`

Expected: `конвейер арта` сообщает неверный размер текущего `folder.png`.

- [x] **Step 3: Подготовить финальный A4-портфель и заменить заглушку**

Из последнего утверждённого генераторного исходника сделать бинарную альфу, импортировать в 42×34 без сглаживания и записать в `art/folder.png`. Удалить отдельный кандидат, чтобы один ассет не хранился дважды.

- [x] **Step 4: Запустить тест и получить зелёный результат**

Run: `tools/test.sh`

Expected: ассет загружается как RGBA 42×34; вывод не содержит неожиданных `SCRIPT ERROR`.

### Task 3: Отрисовка прыжка, переворота и тени

**Files:**
- Modify: `game/world_view.gd`

- [x] **Step 1: Подключить локальное состояние анимации**

Добавить `projectile_age`, `projectile_duration` и отслеживание смены `RunState`. В `advance(delta)` заводить записи новым снарядам, увеличивать возраст существующих и удалять исчезнувшие идентификаторы.

- [x] **Step 2: Отрисовать землю и летящий портфель раздельно**

Тень рисовать в позиции симуляции. Портфель поднять на `ProjectilePose.lift(progress)`, повернуть на `ProjectilePose.rotation(progress)` и вернуть transform после отрисовки. Для полёта влево менять знак угла, не количество оборотов.

- [x] **Step 3: Сохранить анимированный fallback**

Если PNG отсутствует, прямоугольная заглушка использует тот же подъём и угол, чтобы логика представления проверялась даже без `art/`.

- [x] **Step 4: Выполнить полную проверку**

Run:

```bash
tools/test.sh
tools/smoke.sh 180
```

Expected: все headless-тесты проходят без неожиданных ошибок; стенд живёт 180 кадров, а проверка ввода проходит во всех направлениях и раскладках.

- [x] **Step 5: Зафиксировать и отправить**

```bash
git add game/projectile_pose.gd game/world_view.gd tests/test_projectile_pose.gd tests/test_art_library.gd tests/README.md art/folder.png art/README.md docs/superpowers/plans/2026-09-02-briefcase-flight-animation.md
git commit -m "Портфель: прыжок и один переворот"
git push origin main
```
