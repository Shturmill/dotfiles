# shellcheck shell=bash

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

    # Everything hyprland.lua and hypridle.conf call by name.
    # wlogout is AUR-only (install_aur_packages).
    local packages=(
        "git"
        "hyprland"
        "hyprpolkitagent"
        "hyprpicker"
        "awww"
        "kitty"
        "thunar"
        "zed"
        "wireplumber"
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
        "hypridle"
        "wofi"
        "mako"
        "satty"
        "wl-clipboard"
        "cliphist"
        "imagemagick"
        "sqlite"
        "playerctl"
    )

    log_info "Packages: ${packages[*]}"
    log_warn "Arch does not support partial upgrades, so this runs 'pacman -Syu': the whole system, kernel included, is upgraded first"

    if ! confirm "Upgrade the system and install these packages?"; then
        log_info "Package installation skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would run pacman -Syu --needed ${packages[*]}"
        return 0
    fi

    # Pacman shows the whole transaction and asks itself.
    local pacman_flags=(--needed)
    [[ "$ASSUME_DEFAULTS" == true ]] && pacman_flags+=(--noconfirm)

    log_info "Installing packages..."
    if sudo pacman -Syu "${pacman_flags[@]}" "${packages[@]}"; then
        log_info "Packages installed successfully"
    else
        log_error "Failed to install some packages"
        return 1
    fi
}

install_aur_packages() {
    if [[ "$SKIP_AUR" == true ]]; then
        log_info "Skipping AUR packages"
        return 0
    fi

    local packages=("wlogout")

    if [[ "$SKIP_YAY" == true ]] && ! command -v yay &> /dev/null; then
        if [[ "$AUR_REQUESTED" == true ]]; then
            log_error "--only-aur needs yay, which is not installed; run --only-yay first"
            return 1
        fi
        log_warn "yay was skipped and is not installed; skipping AUR packages: ${packages[*]}"
        return 0
    fi

    if [[ "$DRY_RUN" == false ]] && ! command -v yay &> /dev/null; then
        log_error "yay not found, cannot install AUR packages: ${packages[*]}"
        return 1
    fi

    if ! confirm "Install AUR packages (${packages[*]}) with yay?"; then
        log_info "AUR packages skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would run yay -S --needed ${packages[*]}"
        return 0
    fi

    local yay_flags=(--needed)
    [[ "$ASSUME_DEFAULTS" == true ]] && yay_flags+=(--noconfirm)

    if yay -S "${yay_flags[@]}" "${packages[@]}"; then
        log_info "AUR packages installed successfully"
    else
        log_error "Failed to install AUR packages"
        return 1
    fi
}
