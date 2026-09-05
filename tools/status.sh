#!/usr/bin/env bash
# Состояние проекта одной командой. С неё начинается сессия.
#
# Всё здесь — факты из репозитория и прогонов, а не запись, которую кто-то
# поддерживает руками. Записи устаревают в тот день, когда их сделали;
# гит и тесты не врут.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

blue() { printf '\033[1m%s\033[0m\n' "$1"; }

blue "ВЕТКА И СИНХРОНИЗАЦИЯ"
branch="$(git rev-parse --abbrev-ref HEAD)"
dirty="$(git status --short | wc -l | tr -d ' ')"
git fetch -q origin 2>/dev/null || true
ahead="$(git rev-list --count origin/"$branch".."$branch" 2>/dev/null || echo '?')"
behind="$(git rev-list --count "$branch"..origin/"$branch" 2>/dev/null || echo '?')"
echo "  ветка $branch · незакоммичено файлов: $dirty · не отправлено: $ahead · не забрано: $behind"
if [ "$dirty" != "0" ]; then
    git status --short | sed 's/^/    /'
fi

echo ""
blue "ПОСЛЕДНИЕ КОММИТЫ"
git log --format='  %C(dim)%ad%C(reset)  %s' --date=format:'%d.%m %H:%M' -12

echo ""
blue "ПРОВЕРКИ"
failed=0
if out="$(bash tools/test.sh 2>&1)"; then
    echo "  тесты:  $(grep -oE 'ВСЕ ТЕСТЫ ПРОЙДЕНЫ.*' <<< "$out")"
else
    failed=1
    echo "  тесты:  КРАСНЫЕ" >&2
    printf '%s\n' "$out" | tail -15
fi
if out="$(bash tools/smoke.sh 120 2>&1)"; then
    echo "  стенд:  поднимается, ввод работает на трёх раскладках"
else
    failed=1
    echo "  стенд:  СЛОМАН" >&2
    printf '%s\n' "$out" | tail -15
fi

echo ""
blue "ОБЪЁМ"
python3 tools/code_stats.py --print 2>/dev/null | sed -n '3,20p'

echo ""
blue "ЧТО ДАЛЬШЕ"
echo "  Веха и критерий выхода — docs/ROADMAP.md"
echo "  Принятые решения       — docs/DECISIONS.md, нарушать нельзя"
echo "  Что сделано и осталось — раздел «Где мы сейчас» в CLAUDE.md"
exit "$failed"
