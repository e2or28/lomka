#!/usr/bin/env bash
# Пересобрать project.godot: настройки проекта и карта ввода на четверых.
#
# Карта ввода собирается кодом, а не через GUI — таблица лежит в
# tools/input_map.gd, здесь только запуск. Секция [input] со слотами p1–p4
# пересоздаётся целиком, ручные правки в ней будут стёрты.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

# Движок не стартует без project.godot, а генератор — это скрипт движка.
# Поэтому на пустом месте кладётся заготовка, которую генератор перепишет.
if [ ! -f project.godot ]; then
    echo "project.godot отсутствует, кладу заготовку"
    printf 'config_version=5\n\n[application]\n\nconfig/name="Ломка"\n' > project.godot
fi

"$GODOT" --headless --path . --script res://tools/gen_project.gd
