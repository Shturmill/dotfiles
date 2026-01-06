#!/bin/bash

# Yay AUR Helper Installation

install_yay() {
    if [[ "$SKIP_YAY" == true ]]; then
        log_info "Skipping yay installation (--skip-yay flag)"
        return 0
    fi

    log_info "Checking yay AUR helper..."

    if command -v yay &> /dev/null; then
        log_info "yay is already installed"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would install yay"
        return 0
    fi

    log_info "Installing build dependencies for yay..."
    sudo pacman -S --noconfirm --needed git base-devel

    local yay_dir="/tmp/yay-install-$$"

    log_info "Cloning yay repository..."
    if ! git clone https://aur.archlinux.org/yay.git "$yay_dir"; then
        log_error "Failed to clone yay repository"
        return 1
    fi

    log_info "Building and installing yay..."
    (
        cd "$yay_dir"
        if makepkg -si --noconfirm; then
            log_info "yay installed successfully"
        else
            log_error "Failed to build/install yay"
            return 1
        fi
    )

    rm -rf "$yay_dir"
}
