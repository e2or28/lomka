#!/usr/bin/env bash
# Забрать текущее состояние Drive Саши в art/_inbox/.
#
# Drive — канал доставки, а не источник для игры: там исходники по два
# мегабайта, растянутые до 1536x1024, а стенд читает спрайты в родном
# размере. Поэтому сюда, в art/_inbox/ мимо гита, и дальше руками через
# tools/import_*.py — цепочка описана в art/README.md.
#
# Копирование, а не синхронизация: локальные файлы, которых в Drive больше
# нет, остаются лежать. Каталог одноразовый, удалить его можно в любой
# момент. Ключ на чтение выдаётся при настройке (scope 2), поэтому записать
# что-то в Drive этот скрипт не может физически.
#
# Настройка, один раз:
#   brew install rclone
#   rclone config       # n · имя lomka · storage drive · scope 2 (read-only)
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

REMOTE="${LOMKA_DRIVE_REMOTE:-lomka}"
INBOX="${LOMKA_ART_INBOX:-art/_inbox}"

# Папка «игра саша егор» лежит не в моём диске, а в «Доступных мне», и по
# имени rclone её не находит. Адресуемся по идентификатору из ссылки:
# drive.google.com/drive/folders/ЭТО
FOLDER_ID="${LOMKA_DRIVE_FOLDER_ID:-12Q7Niu9iSymqNgisGmIWjBqVDOaxKAOu}"

if ! command -v rclone >/dev/null 2>&1; then
	echo "нет rclone. Поставить: brew install rclone" >&2
	exit 1
fi

if ! rclone listremotes | grep -qx "$REMOTE:"; then
	echo "не настроен remote '$REMOTE'. Завести: rclone config" >&2
	echo "  n · имя $REMOTE · storage drive · scope 2 · остальное по умолчанию" >&2
	exit 1
fi

echo "Drive → $INBOX"
rclone copy -v --drive-root-folder-id "$FOLDER_ID" "$REMOTE:" "$INBOX"

echo
echo "лежит в $INBOX:"
find "$INBOX" -type f | sed "s|^$INBOX/|  |" | sort
echo
echo "дальше руками, в родной размер — см. art/README.md, раздел «Канал Саши»"
