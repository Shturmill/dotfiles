# shellcheck shell=bash

# Configuration Files Copying

# Colours are #@base05@-style placeholders filled from lib/palette.env; only
# names from that file are replaced, so @DEFAULT_AUDIO_SINK@ etc. survives.
render_theme_placeholders() {
    local target="$1"
    local palette="$SOURCE_DIR/lib/palette.env"
    local sed_args=()
    local key value

    while IFS='=' read -r key value; do
        [[ -z "$key" || "$key" == \#* ]] && continue
        sed_args+=(-e "s/@${key}@/${value}/g")
    done < "$palette"

    # A config with no placeholders (satty) makes grep exit 1; pipefail aborts.
    { grep -rlZ -E '@(base0[0-9A-F]|zed_[a-z_]+)@' "$target" 2>/dev/null || true; } |
        xargs -0 -r sed -i "${sed_args[@]}"
}

# sync_tree <stage> <target> <backup>: mv staged files into the target, one
# rename per file, so a watcher never sees an empty dir; unchanged files stay.
sync_tree() {
    local stage="$1"
    local target="$2"
    local backup_name="$3"
    local rel src dst
    local changed=0

    while IFS= read -r -d '' rel; do
        src="$stage/$rel"
        dst="$target/$rel"

        if [[ -f "$dst" ]] && cmp -s "$src" "$dst" &&
            [[ "$(stat -c %a "$src")" == "$(stat -c %a "$dst")" ]]; then
            log_debug "Unchanged: $dst"
            continue
        fi
        changed=$((changed + 1))

        if [[ "$DRY_RUN" == true ]]; then
            log_info "DRY-RUN: Would update $dst"
            continue
        fi

        create_backup "$dst" "$backup_name/$rel"
        mkdir -p "$(dirname "$dst")"
        mv -fT "$src" "$dst"
        record_managed "$dst"
        log_info "Updated: $dst"
    done < <(find "$stage" \( -type f -o -type l \) -printf '%P\0')

    if (( changed == 0 )); then
        log_info "Already up to date: $target"
    fi
}

copy_configs() {
    if [[ "$SKIP_CONFIGS" == true ]]; then
        log_info "Skipping config file copying"
        return 0
    fi

    log_info "Copying configuration files..."

    local config_dir="$SOURCE_DIR/config"

    if [[ ! -d "$config_dir" ]]; then
        log_warn "Config directory not found: $config_dir"
        return 0
    fi

    # Stage inside TARGET_DIR so sync_tree's mv is a same-filesystem rename.
    local stage_parent="$TARGET_DIR"
    if [[ "$DRY_RUN" == true ]]; then
        stage_parent="${TMPDIR:-/tmp}"
    else
        mkdir -p "$TARGET_DIR"
    fi

    (
        local stage
        stage=$(mktemp -d "$stage_parent/.dotfiles-stage.XXXXXXXXXX")
        trap 'rm -rf "$stage"' EXIT

        cp -a "$config_dir/." "$stage/"
        render_theme_placeholders "$stage"
        sync_tree "$stage" "$TARGET_DIR" "config"
    )

    install_scripts
}

# A fresh login shell's PATH, which Hyprland inherits from a TTY or display
# manager. No stdin tty and a timeout, so a tty1 exec stays off.
login_path() {
    local user login_shell
    user=$(id -un)
    login_shell=$(getent passwd "$user" | cut -d: -f7)
    # shellcheck disable=SC2016 # $PATH is for the login shell to expand
    timeout 5 env -i HOME="$HOME" USER="$user" LOGNAME="$user" TERM=dumb \
        "${login_shell:-/bin/bash}" -lc 'printf "%s" "$PATH"' \
        </dev/null 2>/dev/null || true
}

# Helpers the configs call by name (on-ac, cliphist-wofi, zed-recent-projects):
# NixOS packages them, here they go to ~/.local/bin, which must be on PATH.
install_scripts() {
    local bin_dir="$SOURCE_DIR/bin"
    local target_bin="$HOME/.local/bin"

    [[ -d "$bin_dir" ]] || return 0

    local stage_parent="$target_bin"
    if [[ "$DRY_RUN" == true ]]; then
        stage_parent="${TMPDIR:-/tmp}"
    else
        mkdir -p "$target_bin"
    fi

    (
        local stage script
        stage=$(mktemp -d "$stage_parent/.dotfiles-stage.XXXXXXXXXX")
        trap 'rm -rf "$stage"' EXIT

        for script in "$bin_dir"/*; do
            install -m 755 "$script" "$stage/"
        done
        sync_tree "$stage" "$target_bin" "bin"
    )

    local session_path
    session_path=$(login_path)
    case ":$session_path:" in
        *":$target_bin:"*) ;;
        *) log_warn "$target_bin is not on your login PATH; add it, or Hyprland binds that call these scripts will fail" ;;
    esac
}
