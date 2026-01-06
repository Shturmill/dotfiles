#!/bin/bash

# Shell Change to Fish

change_shell() {
    if [[ "$SKIP_SHELL" == true ]]; then
        log_info "Skipping shell change"
        return 0
    fi

    log_info "Checking default shell..."

    if ! command -v fish &> /dev/null; then
        log_warn "Fish shell not found. Install it first."
        return 1
    fi

    local fish_path
    fish_path=$(command -v fish)

    if [[ "$SHELL" == "$fish_path" ]]; then
        log_info "Fish is already the default shell"
        return 0
    fi

    if ! confirm "Change default shell to Fish?"; then
        log_info "Shell change skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would change shell to $fish_path"
        return 0
    fi

    if chsh -s "$fish_path"; then
        log_info "Default shell changed to Fish"
        log_warn "Changes will take effect after logout/login"
    else
        log_error "Failed to change default shell"
        return 1
    fi
}
