#!/usr/bin/env bash
# Ярлык на рабочем столе: запуск стенда двойным кликом.
#
# Собирается настоящий .app, а не .command-скрипт. Разница в том, что
# .command открывает окно Терминала и оставляет его висеть после выхода из
# игры, а .app запускается молча, как обычное приложение, и его иконка
# видна в Dock.
#
# Пути внутрь бандла подставляются абсолютные: приложение стартует без
# shell-окружения, и ни PATH, ни рабочего каталога у него нет.
#
# Пересобирать после переноса проекта или смены спрайта персонажа.
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/godot_env.sh"
cd "$PROJECT_DIR"

APP_NAME="${1:-Ломка}"
APP="$HOME/Desktop/$APP_NAME.app"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$APP_NAME</string>
    <key>CFBundleIdentifier</key><string>dev.lomka.sandbox</string>
    <key>CFBundleVersion</key><string>0.1</string>
    <key>CFBundleShortVersionString</key><string>0.1</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleExecutable</key><string>launch</string>
    <key>CFBundleIconFile</key><string>icon</string>
    <key>LSMinimumSystemVersion</key><string>11.0</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

cat > "$APP/Contents/MacOS/launch" <<LAUNCH
#!/bin/bash
# Собран tools/make_desktop_launcher.sh — правки здесь сотрёт пересборка.
GODOT="$GODOT"
PROJECT="$PROJECT_DIR"

if [ ! -x "\$GODOT" ]; then
    osascript -e 'display alert "Движок не найден" message "Нет GodotSteam по пути:\n$GODOT\n\nСмотри docs/SETUP.md." as critical'
    exit 1
fi
if [ ! -f "\$PROJECT/project.godot" ]; then
    osascript -e 'display alert "Проект не найден" message "Нет project.godot в:\n$PROJECT_DIR\n\nПересобери ярлык: tools/make_desktop_launcher.sh" as critical'
    exit 1
fi

exec "\$GODOT" --path "\$PROJECT"
LAUNCH
chmod +x "$APP/Contents/MacOS/launch"

# Иконка из спрайта персонажа
if [ -f art/player.png ]; then
    python3 tools/make_icon.py art/player.png "$STAGE/icon_1024.png" >/dev/null
    ICONSET="$STAGE/icon.iconset"
    mkdir -p "$ICONSET"
    for size in 16 32 64 128 256 512; do
        sips -z $size $size "$STAGE/icon_1024.png" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
        double=$((size * 2))
        sips -z $double $double "$STAGE/icon_1024.png" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
    done
    iconutil -c icns "$ICONSET" -o "$APP/Contents/Resources/icon.icns"
fi

# Сбросить кэш иконок Finder, иначе он покажет прежнюю
touch "$APP"

echo "Ярлык собран: $APP"
echo "  движок:  $GODOT"
echo "  проект:  $PROJECT_DIR"
echo "  иконка:  $([ -f "$APP/Contents/Resources/icon.icns" ] && echo "из art/player.png" || echo "стандартная")"
