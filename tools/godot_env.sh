# Общая часть для скриптов из tools/. Подключается через source.
#
# Движок — GodotSteam, а не стоковый Godot: это пересобранный движок со
# Steamworks внутри (docs/SETUP.md). Путь переопределяется переменной GODOT.

GODOT="${GODOT:-/Applications/GodotSteam.app/Contents/MacOS/Godot}"
PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [ ! -x "$GODOT" ]; then
    echo "Движок не найден: $GODOT" >&2
    echo "Задай путь переменной GODOT, либо поставь GodotSteam (docs/SETUP.md)." >&2
    exit 127
fi
