#!/usr/bin/env bash
# Полная локальная проверка и единая точка входа для pre-commit/CI.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."

python3 -m unittest discover -s tests/tools -v
bash tools/audit_syntax.sh
bash tools/test.sh
bash tools/smoke.sh 120
