#!/usr/bin/env bash
# Дымовой прогон стенда: запустить главную сцену на N кадров без окна.
#
# tools/test.sh проверяет симуляцию и не касается game/ вообще — по правилу 2
# так и должно быть. Но представление тоже умеет падать: опечатка в _ready,
# несуществующий узел, сигнал не туда. Здесь это ловится за две секунды.
#
# В headless нет ни ввода, ни настоящей отрисовки, поэтому проверяется ровно
# одно: сцена поднимается и живёт N кадров, не сыпля ошибками скриптов.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

FRAMES="${1:-180}"

output="$("$GODOT" --headless --path . --quit-after "$FRAMES" 2>&1)"
code=$?

if [ $code -ne 0 ]; then
    echo "$output"
    echo ""
    echo "СТЕНД НЕ ПОДНЯЛСЯ (код возврата $code)" >&2
    exit $code
fi

# Godot выходит с нулём и на ошибке скрипта — код возврата тут не свидетель
if grep -qE 'SCRIPT ERROR|Parse Error|Failed to load script' <<< "$output"; then
    echo "$output"
    echo ""
    echo "СТЕНД ПОДНЯЛСЯ С ОШИБКАМИ СКРИПТОВ" >&2
    exit 1
fi

if grep -q 'ObjectDB instances were leaked' <<< "$output"; then
    echo "$output"
    echo ""
    echo "СТЕНД ТЕЧЁТ: узлы не освобождены при выходе" >&2
    exit 1
fi

echo "стенд: $FRAMES кадров без ошибок"

# Сквозная проверка: физическая клавиша -> действие -> команда -> симуляция
# -> положение тела. Между «симуляция считает верно» и «на экране едет
# верно» лежит слой представления, и ошибка в нём выглядит как ошибка
# симуляции — искать её будешь не там.
input_output="$("$GODOT" --headless --path . --script res://tools/smoke_input.gd 2>&1)"
input_code=$?

if [ $input_code -ne 0 ] || ! grep -q "ВВОД СТЕНДА В ПОРЯДКЕ" <<< "$input_output"; then
    echo "$input_output"
    echo ""
    echo "СКВОЗНАЯ ПРОВЕРКА ВВОДА НЕ ПРОЙДЕНА" >&2
    exit 1
fi

grep -E "сдвиг|ВВОД СТЕНДА" <<< "$input_output"
exit 0
