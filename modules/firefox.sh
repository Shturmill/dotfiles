# shellcheck shell=bash

# Firefox Preferences Setup
# firefox.txt goes into user.js, not prefs.js: user.js is read every start and
# overrides prefs.js, so nothing to merge and no running browser can undo it.

readonly FIREFOX_BLOCK_BEGIN="// BEGIN dotfiles: firefox.txt"
readonly FIREFOX_BLOCK_END="// END dotfiles"

setup_firefox() {
    if [[ "$SKIP_FIREFOX" == true ]]; then
        log_info "Skipping Firefox setup"
        return 0
    fi

    log_info "Setting up Firefox preferences..."

    # Firefox 147+ keeps profiles under XDG config; older installs in ~/.mozilla
    local ff_profile_dirs=()
    local dir
    for dir in "${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox" "$HOME/.mozilla/firefox"; do
        [[ -d "$dir" ]] && ff_profile_dirs+=("$dir")
    done

    if [[ ${#ff_profile_dirs[@]} -eq 0 ]]; then
        log_error "Firefox profile directory not found (checked ${XDG_CONFIG_HOME:-$HOME/.config}/mozilla/firefox and $HOME/.mozilla/firefox)"
        log_info "Please run Firefox at least once to create a profile, then re-run with --only-firefox"
        return 1
    fi

    # A profile that has been started once has a prefs.js
    local prefs_files=()
    while IFS= read -r -d '' file; do
        prefs_files+=("$file")
    done < <(find "${ff_profile_dirs[@]}" -name 'prefs.js' -type f -print0)

    if [[ ${#prefs_files[@]} -eq 0 ]]; then
        log_error "No Firefox profiles with prefs.js found in ${ff_profile_dirs[*]}"
        return 1
    fi

    # Handle multiple profiles
    local prefs_file="${prefs_files[0]}"
    if [[ ${#prefs_files[@]} -gt 1 ]]; then
        log_warn "Multiple Firefox profiles found:"
        for i in "${!prefs_files[@]}"; do
            echo "  [$i] $(dirname "${prefs_files[$i]}")"
        done
        local selection
        ask selection "Select profile [0]:" 0
        if [[ ! "$selection" =~ ^[0-9]+$ ]] || (( selection >= ${#prefs_files[@]} )); then
            log_error "Invalid Firefox profile selection: $selection"
            return 1
        fi
        prefs_file="${prefs_files[$selection]}"
    fi

    local user_js
    user_js="$(dirname "$prefs_file")/user.js"
    log_info "Using profile: $(dirname "$prefs_file")"

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would write $SOURCE_DIR/firefox.txt into $user_js"
        return 0
    fi

    write_firefox_user_js "$user_js" "$SOURCE_DIR/firefox.txt"

    if is_process_running "firefox"; then
        log_warn "Firefox is running; the preferences apply after it is restarted"
    fi
}

# Replace the dotfiles block in <user.js>, keeping the rest. Built next to the
# old file so the mv is an atomic rename; keeps the old mode (0600 if new).
write_firefox_user_js() {
    local user_js="$1"
    local new_prefs="$2"

    (
        local temp_js
        temp_js=$(mktemp "$user_js.XXXXXXXXXX")
        trap 'rm -f "$temp_js"' EXIT

        {
            if [[ -f "$user_js" ]]; then
                # Exit 3 on a BEGIN without END (the rest would be dropped).
                if ! awk -v begin="$FIREFOX_BLOCK_BEGIN" -v end="$FIREFOX_BLOCK_END" '
                    $0 == begin { skip = 1 }
                    !skip { print }
                    $0 == end { skip = 0 }
                    END { exit skip ? 3 : 0 }
                ' "$user_js"; then
                    log_error "$user_js has '$FIREFOX_BLOCK_BEGIN' without '$FIREFOX_BLOCK_END'; fix it by hand and re-run"
                    exit 1
                fi
            fi
            printf '%s\n' "$FIREFOX_BLOCK_BEGIN"
            # awk, not cat: also terminates a last line without a newline
            awk '{ print }' "$new_prefs"
            printf '%s\n' "$FIREFOX_BLOCK_END"
        } > "$temp_js"

        if [[ -f "$user_js" ]] && cmp -s "$temp_js" "$user_js"; then
            log_info "Firefox preferences already up to date"
            exit 0
        fi

        if [[ -f "$user_js" ]]; then
            create_backup "$user_js" "firefox/$(basename "$(dirname "$user_js")")/user.js"
            chmod --reference="$user_js" "$temp_js"
        fi
        mv -f "$temp_js" "$user_js"
        record_managed "$user_js"
        log_info "Firefox preferences written to $user_js"
    )
}
