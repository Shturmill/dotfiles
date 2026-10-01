#!/bin/bash

# Validation Functions

validate_environment() {
    log_info "Validating environment..."

    # Check if running on Arch-based system
    if [[ ! -f /etc/arch-release ]]; then
        log_warn "Not running on Arch Linux. Some features may not work."
    fi

    # Without pacman only the package-manager-free steps make sense
    if [[ "$NO_PKG" == false ]] && ! command -v pacman &> /dev/null; then
        log_warn "pacman not found. Skipping package installation, only configs and user-level setup will run."
        NO_PKG=true
    fi
    if [[ "$NO_PKG" == true ]]; then
        SKIP_DEPS=true
        SKIP_YAY=true
        SKIP_DOCKER=true
    fi

    # Check if source directory exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory $SOURCE_DIR does not exist"
        exit 1
    fi

    # Check if firefox.txt exists
    if [[ ! -f "$SOURCE_DIR/firefox.txt" ]]; then
        log_warn "firefox.txt not found. Firefox setup will be skipped."
        SKIP_FIREFOX=true
    fi

    # Check if config directory exists
    if [[ ! -d "$SOURCE_DIR/config" ]]; then
        log_warn "Config directory not found. Config copying will be skipped."
        SKIP_CONFIGS=true
    fi

    log_info "Environment validation completed"
}
