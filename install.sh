#!/bin/bash

SOURCE_DIR="$(pwd)"
TARGET_DIR="$HOME/.config"

# sudo pacman -S git firefox telegram-desktop fish waybar docker docker-compose fastfetch brightnessctl

# finding prefs.js
FF_PROFILE_DIR="$HOME/.mozilla/firefox"
PREFS_FILE=$(find "$FF_PROFILE_DIR" -name 'prefs.js' -type f | head -n 1)

if [ -z "$PREFS_FILE" ]; then
    echo "Ошибка: файл prefs.js не найден в $FF_PROFILE_DIR!"
    exit 1
fi

echo "file of prefs.js was finded at: $PREFS_FILE"
cat $SOURCE_DIR/firefox.txt >> "$PREFS_FILE"
echo "settings are applyed for firefox"

echo "changing shell to fish"
chsh -s /usr/bin/fish

#cp -R "$SOURCE_DIR" "$TARGET_DIR/" 
echo "do you want to reboot for applying settings? (Y/n)"
if ("/n"); then
    reboot
fi