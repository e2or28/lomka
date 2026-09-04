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
set -uo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

REMOTE="${LOMKA_DRIVE_REMOTE:-lomka}"
FOLDER_ID="${LOMKA_DRIVE_FOLDER_ID:-12Q7Niu9iSymqNgisGmIWjBqVDOaxKAOu}"
PERIOD="${1:-120}"

STATE="$(mktemp)"
trap 'rm -f "$STATE" "$STATE.new"' EXIT

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
	sleep "$PERIOD"
	snapshot > "$STATE.new"
	# Пустой снимок — это сеть отвалилась, а не Саша всё удалил.
	[ -s "$STATE.new" ] || continue
	comm -13 "$STATE" "$STATE.new" | while IFS=$'\t' read -r path size modtime; do
		echo "DRIVE: $path  ($size байт, $modtime)"
	done
	mv "$STATE.new" "$STATE"
done
