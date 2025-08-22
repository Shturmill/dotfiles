#!/bin/bash

SOURCE_DIR="$(pwd)"
TARGET_DIR="$HOME/.config"

# sudo pacman -S git firefox telegram-desktop fish waybar 

# Ищем prefs.js в профиле Firefox и переносим настройки из firefox.txt 
FF_PROFILE_DIR="$HOME/.mozilla/firefox"
PREFS_FILE=$(find "$FF_PROFILE_DIR" -name 'prefs.js' -type f | head -n 1)

if [ -z "$PREFS_FILE" ]; then
    echo "Ошибка: файл prefs.js не найден в $FF_PROFILE_DIR!"
    exit 1
fi

echo "Найден файл настроек: $PREFS_FILE"
cat firefox.txt >> "$PREFS_FILE"
echo "Настройки успешно добавлены в $PREFS_FILE"

#cp -R "$SOURCE_DIR" "$TARGET_DIR/" 

# reboot 