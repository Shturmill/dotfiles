#!/bin/bash

# Utility Functions

confirm() {
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would ask: $1"
        return 0
    fi

    local prompt="${1:-Do you want to continue?}"
    local default="${2:-Y}"

    if [[ "$default" == "Y" ]]; then
        read -p "$prompt [Y/n] " -n 1 -r
    else
        read -p "$prompt [y/N] " -n 1 -r
    fi
    echo

    if [[ -z "$REPLY" ]]; then
        [[ "$default" == "Y" ]] && return 0 || return 1
    fi

    [[ $REPLY =~ ^[Yy]$ ]] && return 0 || return 1
}

create_backup() {
    local file="$1"
    if [[ -e "$file" ]]; then
        local backup_path="$BACKUP_DIR/$(basename "$file").$(date +%s)"

        if [[ "$DRY_RUN" == true ]]; then
            log_debug "DRY-RUN: Would backup $file to $backup_path"
        else
            mkdir -p "$BACKUP_DIR"
            cp -a "$file" "$backup_path"
            log_info "Backed up: $file -> $backup_path"
        fi
    fi
}

is_process_running() {
    local process_name="$1"
    pgrep -x "$process_name" > /dev/null 2>&1
}

ask_for_reboot() {
    if [[ "$SKIP_REBOOT" == true ]] || [[ "$DRY_RUN" == true ]]; then
        log_info "Reboot prompt skipped"
        return 0
    fi

    if confirm "Setup completed. Reboot now?"; then
        log_info "Rebooting system..."
        sudo reboot
    else
        log_info "Reboot cancelled. Remember to reboot for all changes to take effect."
    fi
}
