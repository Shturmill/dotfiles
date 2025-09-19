#!/bin/bash

# set -e: Немедленно выйти, если команда завершается с ошибкой.
# set -o pipefail: Выйти, если команда в конвейере (pipe) завершается с ошибкой.

set -e
set -o pipefail

# --- Переменные и константы ---
SOURCE_DIR=$(dirname "$(realpath "$0")")
TARGET_DIR="$HOME/.config"
readonly SOURCE_DIR
readonly TARGET_DIR

# --- Функции ---

# Функция для вывода сообщений
info() {
    printf "\n✅ %s\n" "$1"
}

# Функция для вывода ошибок
error() {
    printf "\n❌ %s\n" "$1" >&2
    exit 1
}

# Функция для установки зависимостей
install_dependencies() {
    info "Проверка и установка зависимостей..."
    if ! command -v pacman &> /dev/null; then
        error "Менеджер пакетов pacman не найден. Пожалуйста, установите зависимости вручную."
    fi

    read -p "Хотите установить рекомендованные пакеты (git, firefox, fish и т.д.)? [Y/n] " -n 1 -r
    echo # Переход на новую строку
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        sudo pacman -Syu --noconfirm git firefox chromium telegram-desktop fish waybar docker docker-compose fastfetch brightnessctl power-profile-daemon 
    else
        info "Установка пакетов пропущена."
    fi
}

# Функция для настройки Firefox
setup_firefox() {
    info "Настройка Firefox..."
    local ff_profile_dir="$HOME/.mozilla/firefox"
    
    # Ищем все файлы prefs.js
    local prefs_files
    prefs_files=$(find "$ff_profile_dir" -name 'prefs.js' -type f)

    if [ -z "$prefs_files" ]; then
        error "Файл prefs.js не найден в $ff_profile_dir. Убедитесь, что Firefox был запущен хотя бы раз."
    fi

    # Если найдено несколько профилей, предупредим пользователя
    if [ "$(echo "$prefs_files" | wc -l)" -gt 1 ]; then
        echo "Найдено несколько профилей Firefox. Настройки будут применены к первому из списка:"
        echo "$prefs_files"
    fi

    local prefs_file
    prefs_file=$(echo "$prefs_files" | head -n 1)

    info "Найден файл настроек: $prefs_file"
    
    # Создаем резервную копию перед изменениями
    cp "$prefs_file" "$prefs_file.bak.$(date +%F_%T)"
    info "Создана резервная копия: $prefs_file.bak"

    # Добавляем настройки из файла
    cat "$SOURCE_DIR/firefox.txt" >> "$prefs_file"
    info "Настройки для Firefox применены."
}

# Функция для смены оболочки на Fish
change_shell() {
    info "Смена оболочки на Fish..."
    # Используем `which` для поиска пути к fish.
    local fish_path
    fish_path=$(which fish)

    if [ -z "$fish_path" ]; then
        error "Оболочка fish не найдена. Пожалуйста, установите ее."
    fi

    if [ "$SHELL" != "$fish_path" ]; then
        chsh -s "$fish_path"
        info "Оболочка по умолчанию изменена на Fish. Изменения вступят в силу после перезапуска сессии."
    else
        info "Fish уже является оболочкой по умолчанию."
    fi
}

# Функция для копирования конфигурационных файлов
copy_configs() {
    info "Копирование конфигурационных файлов..."

    mkdir -p "$TARGET_DIR"

    # Копируем содержимое, создавая бэкапы существующих файлов
    # --backup=numbered создает файлы вида `file.~1~`, `file.~2~`
    cp -vr --backup=numbered "$SOURCE_DIR/"* "$TARGET_DIR/"
    info "Все конфигурации скопированы в $TARGET_DIR"
}

# Функция для запроса перезагрузки
ask_for_reboot() {
    read -p "Настройка завершена. Хотите перезагрузить систему сейчас? [Y/n] " -n 1 -r
    echo 
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        info "Перезагрузка..."
        reboot
    else
        info "Перезагрузка отменена."
    fi
}

main() {
    install_dependencies
    setup_firefox
    change_shell
    copy_configs
    ask_for_reboot
}

main