#!/usr/bin/env bash
# Прогнать автобот: одна комната, одна стратегия, разрез по сборкам.
#
# Обёртка проверяет сентинел, а не только код возврата: молча не
# состоявшийся прогон даёт пустую выборку, которую примут за результат,
# и это хуже упавшего (docs/LEVEL_EDITOR.md).
#
#   tools/autobot.sh                        все сборки, по 5 сидов
#   tools/autobot.sh --seeds 20             больше выборка
#   tools/autobot.sh --build кольт          одна сборка
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

output="$("$GODOT" --headless --path . --script res://tools/autobot.gd -- "$@" 2>&1)"
code=$?

echo "$output"

if [ $code -ne 0 ]; then
    echo "" >&2
    echo "АВТОБОТ УПАЛ (код возврата $code)" >&2
    exit $code
fi

if grep -qE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script' <<< "$output"; then
    echo "АВТОБОТ С ОШИБКАМИ СКРИПТОВ: выборке верить нельзя." >&2
    exit 1
fi

if ! grep -q "АВТОБОТ ЗАКОНЧИЛ" <<< "$output"; then
    echo "" >&2
    echo "АВТОБОТ НЕ ДОШЁЛ ДО КОНЦА: движок вышел с нулём, но прогон не отчитался." >&2
    exit 1
fi

exit 0
