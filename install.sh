#!/bin/bash

# set -e: Exit immediately if a command exits with a non-zero status.
# set -o pipefail: Exit if any command in a pipeline fails.

set -e
set -o pipefail

# --- Variables and constants ---
SOURCE_DIR=$(dirname "$(realpath "$0")")
TARGET_DIR="$HOME/.config"
readonly SOURCE_DIR
readonly TARGET_DIR

# --- Functions ---

# Function for outputting messages
info() {
    printf "\n[OK] %s\n" "$1"
}

# Function for outputting errors
error() {
    printf "\n[ERROR] %s\n" "$1" >&2
    exit 1
}



# Function for installing dependencies
install_dependencies() {
    info "Checking and installing dependencies..."
    if ! command -v pacman &> /dev/null; then
        error "Package manager pacman not found. Please install dependencies manually."
    fi

    read -p "Do you want to install recommended packages (git, firefox, fish, etc.)? [Y/n] " -n 1 -r
    echo # New line
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        sudo pacman -Syu --noconfirm git firefox chromium telegram-desktop fish waybar docker docker-compose fastfetch brightnessctl power-profile-daemon hyprshot hyprlock
    else
        info "Package installation skipped."
    fi
}

# Function for installing yay (AUR helper)
install_yay() {
    info "Installing yay (AUR helper)..."
    
    # Check if yay is already installed
    if command -v yay &> /dev/null; then
        info "yay is already installed."
        return 0
    fi

    # Install dependencies for building from AUR
    info "Installing dependencies for yay..."
    sudo pacman -S --noconfirm --needed git base-devel

    # Clone yay repository
    local yay_dir="/tmp/yay"
    if [ -d "$yay_dir" ]; then
        rm -rf "$yay_dir"
    fi
    
    git clone https://aur.archlinux.org/yay.git "$yay_dir"
    if [ $? -ne 0 ]; then
        error "Failed to clone yay repository."
    fi

    # Build and install yay
    cd "$yay_dir"
    makepkg -si --noconfirm
    if [ $? -ne 0 ]; then
        error "Failed to install yay."
    fi

    # Clean up
    cd /
    rm -rf "$yay_dir"
    
    info "yay installed successfully."
}

# Function for setting up Firefox
setup_firefox() {
    info "Setting up Firefox..."
    local ff_profile_dir="$HOME/.mozilla/firefox"
    
    # Find all prefs.js files
    local prefs_files
    prefs_files=$(find "$ff_profile_dir" -name 'prefs.js' -type f)

    if [ -z "$prefs_files" ]; then
        error "prefs.js file not found in $ff_profile_dir. Make sure Firefox has been run at least once."
    fi

    # If multiple profiles found, warn the user
    if [ "$(echo "$prefs_files" | wc -l)" -gt 1 ]; then
        echo "Multiple Firefox profiles found. Settings will be applied to the first one in the list:"
        echo "$prefs_files"
    fi

    local prefs_file
    prefs_file=$(echo "$prefs_files" | head -n 1)

    info "Settings file found: $prefs_file"
    
    # Create backup before making changes
    cp "$prefs_file" "$prefs_file.bak.$(date +%F_%T)"
    info "Backup created: $prefs_file.bak"

    # Add settings from file
    cat "$SOURCE_DIR/firefox.txt" >> "$prefs_file"
    info "Firefox settings applied."
}

# Function for changing shell to Fish
change_shell() {
    info "Changing shell to Fish..."
    # Use `which` to find fish path
    local fish_path
    fish_path=$(which fish)

    if [ -z "$fish_path" ]; then
        error "Fish shell not found. Please install it."
    fi

    if [ "$SHELL" != "$fish_path" ]; then
        chsh -s "$fish_path"
        info "Default shell changed to Fish. Changes will take effect after session restart."
    else
        info "Fish is already the default shell."
    fi
}

# Function for copying configuration files
copy_configs() {
    info "Copying configuration files..."

    mkdir -p "$TARGET_DIR"

    # Copy content, creating backups of existing files
    # --backup=numbered creates files like `file.~1~`, `file.~2~`
    cp -vr --backup=numbered "$SOURCE_DIR/config"* "$TARGET_DIR/"
    info "All configurations copied to $TARGET_DIR"
}

# Function for asking for reboot
ask_for_reboot() {
    read -p "Setup completed. Do you want to reboot the system now? [Y/n] " -n 1 -r
    echo 
    if [[ $REPLY =~ ^[Yy]$ || -z $REPLY ]]; then
        info "Rebooting..."
        reboot
    else
        info "Reboot cancelled."
    fi
}

main() {
    install_dependencies
    install_yay
    setup_firefox
    change_shell
    copy_configs
    ask_for_reboot
}

main