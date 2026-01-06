#!/bin/bash

# Firefox Preferences Setup

setup_firefox() {
    if [[ "$SKIP_FIREFOX" == true ]]; then
        log_info "Skipping Firefox setup"
        return 0
    fi

    log_info "Setting up Firefox preferences..."

    # Check if Firefox is running
    if is_process_running "firefox"; then
        log_warn "Firefox is currently running!"
        if confirm "Firefox must be closed to apply settings. Close it now?"; then
            if [[ "$DRY_RUN" == false ]]; then
                killall firefox 2>/dev/null || true
                sleep 2
            fi
        else
            log_warn "Firefox setup skipped - browser is running"
            return 0
        fi
    fi

    local ff_profile_dir="$HOME/.mozilla/firefox"

    if [[ ! -d "$ff_profile_dir" ]]; then
        log_error "Firefox profile directory not found: $ff_profile_dir"
        log_info "Please run Firefox at least once to create a profile"
        return 1
    fi

    # Find all prefs.js files
    local prefs_files=()
    while IFS= read -r -d '' file; do
        prefs_files+=("$file")
    done < <(find "$ff_profile_dir" -name 'prefs.js' -type f -print0)

    if [[ ${#prefs_files[@]} -eq 0 ]]; then
        log_error "No prefs.js files found in $ff_profile_dir"
        return 1
    fi

    # Handle multiple profiles
    local prefs_file="${prefs_files[0]}"
    if [[ ${#prefs_files[@]} -gt 1 ]]; then
        log_warn "Multiple Firefox profiles found:"
        for i in "${!prefs_files[@]}"; do
            echo "  [$i] ${prefs_files[$i]}"
        done
        echo -n "Select profile [0]: "
        read -r selection
        selection=${selection:-0}
        prefs_file="${prefs_files[$selection]}"
    fi

    log_info "Using profile: $prefs_file"

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would modify $prefs_file"
        return 0
    fi

    # Create backup
    create_backup "$prefs_file"

    # Smart merge: remove duplicate preferences
    local temp_prefs="/tmp/firefox_prefs_merged_$$"
    local new_prefs="$SOURCE_DIR/firefox.txt"

    log_info "Merging preferences (avoiding duplicates)..."

    # Extract preference keys from new prefs
    local new_keys=()
    while IFS= read -r line; do
        if [[ "$line" =~ user_pref\(\"([^\"]+)\" ]]; then
            new_keys+=("${BASH_REMATCH[1]}")
        fi
    done < "$new_prefs"

    # Copy existing prefs, excluding ones we're about to add
    while IFS= read -r line; do
        local skip=false
        for key in "${new_keys[@]}"; do
            if [[ "$line" =~ user_pref\(\"$key\" ]]; then
                skip=true
                log_debug "Removing duplicate preference: $key"
                break
            fi
        done
        if [[ "$skip" == false ]]; then
            echo "$line" >> "$temp_prefs"
        fi
    done < "$prefs_file"

    # Append new preferences
    echo "" >> "$temp_prefs"
    echo "// Added by dotfiles installer on $(date)" >> "$temp_prefs"
    cat "$new_prefs" >> "$temp_prefs"

    # Replace original file
    mv "$temp_prefs" "$prefs_file"

    log_info "Firefox preferences applied successfully"
}
