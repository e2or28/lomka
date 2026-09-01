#!/usr/bin/env bash
# Пересобрать эталонный сейв в tests/fixtures/.
#
# Осознанное действие: пересборка означает «формат сейва изменился, и я это
# подтверждаю». Если тест круговорота покраснел неожиданно — чинить код.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

"$GODOT" --headless --path . --script res://tools/gen_fixture.gd
