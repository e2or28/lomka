#!/usr/bin/env bash
# Аудит на синтаксис Godot 3.
#
# В интернете доминируют примеры под Godot 3, и генерация кода стабильно
# скатывается в её синтаксис (см. «Ловушки» в CLAUDE.md). Часть таких ошибок
# движок ловит разбором, часть — нет: `.empty()` на строке разберётся и
# упадёт в рантайме, а `instance()` найдётся не сразу.
set -uo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

# Разделитель — «::», а не «|»: вертикальная черта нужна самим шаблонам
# для альтернации, и на ней разбор строки разъезжается.
declare -a PATTERNS=(
    'export var::синтаксис Godot 3: используй @export'
    'onready var::синтаксис Godot 3: используй @onready'
    '\byield\(::синтаксис Godot 3: используй await'
    'KinematicBody2D|KinematicBody::Godot 3: используй CharacterBody2D'
    'PoolStringArray|PoolByteArray|PoolIntArray|PoolRealArray::Godot 3: используй Packed*Array'
    '\bsetget\b::Godot 3: используй свойства с get/set'
    '\.instance\(\)::Godot 3: используй instantiate()'
    '\.empty\(\)::Godot 3: используй is_empty()'
    '^class_name ::глобальные имена не резолвятся headless — используй const X = preload(...)'
    'OS\.get_ticks::бери время из симуляции, а не из системных часов'
)

fail=0
for entry in "${PATTERNS[@]}"; do
    pattern="${entry%%::*}"
    message="${entry##*::}"
    if hits=$(grep -rnE "$pattern" --include='*.gd' sim tests tools game 2>/dev/null); then
        echo "$hits" | while IFS= read -r line; do
            echo "  $line" >&2
        done
        echo "    ^ $message" >&2
        fail=1
    fi
done

if [ $fail -ne 0 ]; then
    echo "" >&2
    echo "АУДИТ СИНТАКСИСА НЕ ПРОЙДЕН" >&2
    exit 1
fi

# Разбор каждого скрипта движком. Ловит то, чего не видит grep: неверный
# вывод типа, обращение к несуществующему методу, битый extends. Дешевле
# любого прогона и называет файл и строку.
checked=0
for script in $(find sim game tools tests -name '*.gd' | sort); do
    out="$("$GODOT" --headless --path . --check-only --script "res://$script" 2>&1)"
    if grep -qE 'Parse Error|Compile Error' <<< "$out"; then
        echo "  $script:" >&2
        grep -E 'Parse Error|Compile Error' <<< "$out" | sed 's/^/    /' >&2
        fail=1
    fi
    checked=$((checked + 1))
done

if [ $fail -ne 0 ]; then
    echo "" >&2
    echo "АУДИТ СИНТАКСИСА НЕ ПРОЙДЕН" >&2
    exit 1
fi

echo "аудит синтаксиса: чисто, разобрано $checked скриптов"
exit 0
