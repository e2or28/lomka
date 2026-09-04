#!/usr/bin/env bash
# Следить за папкой Саши на Drive: печатать строку на каждый новый или
# изменившийся файл. Каждая такая строка будит Клода — скрипт написан под
# его инструмент слежения, а не для чтения человеком.
#
#     tools/watch_art.sh [СЕКУНД]      по умолчанию 120
#
# Опрос, а не подписка. Настоящий вебхук от Google требует публичного
# HTTPS-адреса, отдельного ключа с правом записи и продления канала раз
# в сутки; всё это ради задержки, которой никто не заметит — Саша
# выкладывает файлы минутами, а не миллисекундами.
#
# Удалённое в Drive не печатается: пропажу файла разбирать нечего, а шум
# от переименований был бы двойным.
#
# Наблюдатель на машине один, и последний запуск побеждает: новая сессия
# Клода забирает слежение себе, прежняя об этом узнаёт и выходит. Иначе два
# Клода разбирали бы одну заливку, каждый со своей копией снимка, и могли бы
# одновременно импортировать один набор и подраться в гите.
#
# Побеждает именно новый, а не первый занявший: сессии закрывают и открывают
# по десять раз на дню, и правило «первый держит замок» означало бы, что
# слежение навсегда осталось в той вкладке, которую уже закрыли.
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

REMOTE="${LOMKA_DRIVE_REMOTE:-lomka}"
FOLDER_ID="${LOMKA_DRIVE_FOLDER_ID:-12Q7Niu9iSymqNgisGmIWjBqVDOaxKAOu}"
PERIOD="${1:-120}"

LOCK="${TMPDIR:-/tmp}/lomka-watch-art.pid"
OLD="$(cat "$LOCK" 2>/dev/null || true)"
if [ -n "$OLD" ] && kill -0 "$OLD" 2>/dev/null; then
	echo "DRIVE: забираю слежение у прежней сессии, pid $OLD"
	kill "$OLD" 2>/dev/null
	# Ждём, пока прежний уйдёт сам и снимет свой замок: перехватить его
	# раньше значит подставить свой pid под чужой trap EXIT.
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		kill -0 "$OLD" 2>/dev/null || break
		sleep 0.3
	done
	kill -9 "$OLD" 2>/dev/null
fi

STATE="$(mktemp)"
echo $$ > "$LOCK"
# Замок снимается и по обычному выходу, и по перехвату. Брошенный от
# убитого насмерть процесса перезаписывается: живость проверяется по pid.
trap 'rm -f "$STATE" "$STATE.new" "$LOCK"' EXIT
trap 'echo "DRIVE: слежение перехвачено другой сессией, выхожу"; exit 0' TERM

snapshot() {
	rclone lsjson -R --files-only --drive-root-folder-id "$FOLDER_ID" "$REMOTE:" 2>/dev/null \
		| jq -r '.[] | "\(.Path)\t\(.Size)\t\(.ModTime)"' | sort
}

snapshot > "$STATE"
if [ ! -s "$STATE" ]; then
	echo "DRIVE: папка не читается — проверь rclone, см. docs/SETUP.md"
	exit 1
fi
echo "DRIVE: слежу, $(wc -l < "$STATE" | tr -d ' ') файлов, опрос раз в ${PERIOD}с"

while true; do
	# Сон в фоне и wait: на простом sleep bash откладывает обработку
	# сигнала до конца сна, и перехват ждал бы полный период.
	sleep "$PERIOD" & wait $!
	snapshot > "$STATE.new"
	# Пустой снимок — это сеть отвалилась, а не Саша всё удалил.
	[ -s "$STATE.new" ] || continue
	comm -13 "$STATE" "$STATE.new" | while IFS=$'\t' read -r path size modtime; do
		echo "DRIVE: $path  ($size байт, $modtime)"
	done
	mv "$STATE.new" "$STATE"
done
