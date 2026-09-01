#!/usr/bin/env bash
# Аудит на синтаксис Godot 3.
#
# В интернете доминируют примеры под Godot 3, и генерация кода стабильно
# скатывается в её синтаксис (см. «Ловушки» в CLAUDE.md). Часть таких ошибок
# движок ловит разбором, часть — нет: `.empty()` на строке разберётся и
# упадёт в рантайме, а `instance()` найдётся не сразу.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

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

echo "аудит синтаксиса: чисто"
exit 0
