# shellcheck shell=bash

# Validation Functions

validate_environment() {
    log_info "Validating environment..."

    # Require an Arch-based system
    if [[ ! -f /etc/arch-release ]]; then
        log_warn "Not running on Arch Linux. Some features may not work."
    fi

    # Without pacman, only package-manager-free steps make sense
    if [[ "$NO_PKG" == false ]] && ! command -v pacman &> /dev/null; then
        log_warn "pacman not found. Skipping package installation, only configs and user-level setup will run."
        NO_PKG=true
    fi
    if [[ "$NO_PKG" == true ]]; then
        SKIP_DEPS=true
        SKIP_YAY=true
        SKIP_AUR=true
        SKIP_DOCKER=true
    fi

    # No terminal: nobody can answer pacman, and guessing "yes" is worse.
    if [[ ! -t 0 ]] && [[ "$ASSUME_DEFAULTS" == false ]] && [[ "$DRY_RUN" == false ]]; then
        log_error "stdin is not a terminal; run interactively or pass --defaults"
        exit 1
    fi

    # Check source directory exists
    if [[ ! -d "$SOURCE_DIR" ]]; then
        log_error "Source directory $SOURCE_DIR does not exist"
        exit 1
    fi

    # Check firefox.txt exists
    if [[ ! -f "$SOURCE_DIR/firefox.txt" ]]; then
        log_warn "firefox.txt not found. Firefox setup will be skipped."
        SKIP_FIREFOX=true
    fi

    # Check config directory exists
    if [[ ! -d "$SOURCE_DIR/config" ]]; then
        log_warn "Config directory not found. Config copying will be skipped."
        SKIP_CONFIGS=true
    fi

    log_info "Environment validation completed"
}
