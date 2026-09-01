#!/usr/bin/env bash
# Поставить git-хуки из tools/hooks/.
#
# Хуки не хранятся в .git/hooks под гитом, поэтому их ставят ссылкой:
# правка в tools/hooks/ сразу вступает в силу и видна в диффе.
set -euo pipefail

ROOT="$(git rev-parse --show-toplevel)"
cd "$ROOT"

for hook in tools/hooks/*; do
    name="$(basename "$hook")"
    target=".git/hooks/$name"
    ln -sf "../../$hook" "$target"
    chmod +x "$hook"
    echo "поставлен $target -> $hook"
done
