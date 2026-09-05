#!/usr/bin/env bash
# Прогнать headless-тесты.
#
# Обёртка нужна из-за особенности движка: если скрипт не разобрался
# (например, опечатка в GDScript), Godot ругается в stderr и выходит с нулём.
# Голый код возврата такому запуску верить нельзя, поэтому проверяются оба
# признака — код возврата и сентинел в последних строках вывода.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

output="$("$GODOT" --headless --path . --script res://tests/run_all.gd 2>&1)"
code=$?

echo "$output"

if [ $code -ne 0 ]; then
    echo ""
    echo "ТЕСТЫ УПАЛИ (код возврата $code)" >&2
    exit $code
fi

if grep -qE 'SCRIPT ERROR|Parse Error|Compile Error|Failed to load script' <<< "$output"; then
    echo "ТЕСТЫ С ОШИБКАМИ СКРИПТОВ: сентинел не отменяет ошибку вложенного вызова." >&2
    exit 1
fi

if ! grep -q "ВСЕ ТЕСТЫ ПРОЙДЕНЫ" <<< "$output"; then
    echo ""
    echo "ТЕСТЫ НЕ ДОШЛИ ДО КОНЦА: движок вышел с нулём, но харнесс не отчитался." >&2
    echo "Обычно это значит, что скрипт не разобрался — смотри ошибки выше." >&2
    exit 1
fi

exit 0
