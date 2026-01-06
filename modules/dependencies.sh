#!/bin/bash

# Package Dependencies Installation

install_dependencies() {
    if [[ "$SKIP_DEPS" == true ]]; then
        log_info "Skipping dependency installation (--skip-deps flag)"
        return 0
    fi

    log_info "Checking dependencies..."

    if ! command -v pacman &> /dev/null; then
        log_error "pacman not found. This script requires Arch Linux."
        exit 1
    fi

    local packages=(
        "git"
        "firefox"
        "chromium"
        "telegram-desktop"
        "fish"
        "waybar"
        "fastfetch"
        "brightnessctl"
        "power-profiles-daemon"
        "hyprshot"
        "hyprlock"
    )

    if ! confirm "Install recommended packages (${packages[*]})?"; then
        log_info "Package installation skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would install packages: ${packages[*]}"
        return 0
    fi

    log_info "Installing packages..."
    if sudo pacman -Syu --noconfirm --needed "${packages[@]}"; then
        log_info "Packages installed successfully"
    else
        log_error "Failed to install some packages"
        return 1
    fi
}
