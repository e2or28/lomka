#!/usr/bin/env bash
# Пересобрать сцены стенда. Нужно после переименования скриптов game/.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

"$GODOT" --headless --path . --script res://tools/gen_scenes.gd
