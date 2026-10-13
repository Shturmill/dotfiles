# shellcheck shell=bash

# Utility Functions

# Drop pending input so a stale Enter cannot answer the next prompt.
flush_input() {
    [[ -t 0 ]] || return 0
    local _
    while read -r -t 0.01 -n 10000 _; do :; done
}

# ask <var> <prompt> [default]: read a line into <var>. --defaults takes the
# default without reading (validate_environment needs a terminal otherwise).
ask() {
    local -n _answer="$1"
    local prompt="$2"
    local default="${3:-}"

    if [[ "$ASSUME_DEFAULTS" == true ]]; then
        _answer="$default"
        log_info "$prompt ${default:-<empty>} (default)"
        return 0
    fi

    flush_input
    read -r -p "$prompt " _answer || _answer=""
    _answer="${_answer:-$default}"
}

confirm() {
    local prompt="${1:-Do you want to continue?}"
    local default="${2:-Y}"
    local hint="[Y/n]"
    local reply

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would ask: $prompt"
        return 0
    fi

    [[ "$default" == "Y" ]] || hint="[y/N]"

    while true; do
        ask reply "$prompt $hint" "$default"
        case "$reply" in
            [Yy]|[Yy][Ee][Ss]) return 0 ;;
            [Nn]|[Nn][Oo]) return 1 ;;
            *) log_warn "Please answer y or n" ;;
        esac
    done
}

# Paths the installer wrote; never treated as the user's original.
MANAGED_LIST="$BACKUP_ROOT/managed.list"

record_managed() {
    [[ "$DRY_RUN" == true ]] && return 0
    mkdir -p "$BACKUP_ROOT"
    if [[ -f "$MANAGED_LIST" ]] && grep -qxF -- "$1" "$MANAGED_LIST"; then
        return 0
    fi
    printf '%s\n' "$1" >> "$MANAGED_LIST"
}

# Pre-2.1 installers: <name>.<epoch> run dirs hold the user's only configs.
# Mark the files we replaced as managed, then move the dir to original/legacy/.
migrate_legacy_backups() {
    local dir entry name rel is_legacy
    local moved=0

    [[ "$DRY_RUN" == true ]] && return 0
    [[ -d "$BACKUP_ROOT" ]] || return 0

    for dir in "$BACKUP_ROOT"/[0-9]*; do
        [[ -d "$dir" ]] || continue
        is_legacy=false

        for entry in "$dir"/*; do
            name=${entry##*/}
            [[ "$name" =~ ^(.+)\.[0-9]+$ ]] || continue
            is_legacy=true
            name=${BASH_REMATCH[1]}
            [[ -d "$SOURCE_DIR/config/$name" ]] || continue
            while IFS= read -r -d '' rel; do
                record_managed "$TARGET_DIR/$name/$rel"
            done < <(find "$SOURCE_DIR/config/$name" \( -type f -o -type l \) -printf '%P\0')
        done

        [[ "$is_legacy" == true ]] || continue
        mkdir -p "$BACKUP_ROOT/original/legacy"
        mv -- "$dir" "$BACKUP_ROOT/original/legacy/"
        moved=$((moved + 1))
    done

    if (( moved > 0 )); then
        log_warn "Moved $moved backup run(s) of the previous installer to $BACKUP_ROOT/original/legacy/; they hold your configs from before it, and are never pruned"
    fi
}

# Keep the user's first copy of a file in original/<name>, outside the pruned
# run directories, so it survives later runs.
save_original() {
    local file="$1"
    local name="$2"
    local orig="$BACKUP_ROOT/original/$name"

    [[ "$DRY_RUN" == true ]] && return 0
    [[ -e "$orig" ]] && return 0
    if [[ -f "$MANAGED_LIST" ]] && grep -qxF -- "$file" "$MANAGED_LIST"; then
        return 0
    fi
    mkdir -p "$(dirname "$orig")"
    cp -a "$file" "$orig"
    log_info "Saved original: $file -> $orig"
}

# create_backup <path> [name]: copy <path> into this run's backup dir. Pass a
# relative name when basenames collide (mako/config, wofi/config).
create_backup() {
    local file="$1"
    local name="${2:-$(basename "$file")}"
    local backup_path="$BACKUP_DIR/$name"

    [[ -e "$file" ]] || return 0
    save_original "$file" "$name"

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would backup $file to $backup_path"
    else
        mkdir -p "$(dirname "$backup_path")"
        cp -a "$file" "$backup_path"
        log_info "Backed up: $file -> $backup_path"
    fi
}

# prune_old <dir> <keep> <glob>: keep the newest <keep> entries matching <glob>.
# Names are start times, so name order is age order.
prune_old() {
    local dir="$1"
    local keep="$2"
    local glob="$3"
    local entries=()
    local i

    [[ -d "$dir" ]] || return 0
    mapfile -t entries < <(find "$dir" -mindepth 1 -maxdepth 1 -name "$glob" -printf '%f\n' | sort)

    for (( i = 0; i < ${#entries[@]} - keep; i++ )); do
        rm -rf -- "${dir:?}/${entries[i]}"
        log_debug "Pruned old entry: $dir/${entries[i]}"
    done
}

is_process_running() {
    local process_name="$1"
    pgrep -x "$process_name" > /dev/null 2>&1
}

# ERR trap: report where set -e stopped a step, unless the step logged its own
# failure (return 1 inside run_step) or failed inside a ( ... ) block.
on_error() {
    local status="$1"
    local line="$2"
    [[ "${FUNCNAME[1]:-}" == "run_step" ]] && return 0
    [[ "$BASH_COMMAND" == "("* ]] && return 0
    log_error "'$BASH_COMMAND' failed (exit $status) at ${BASH_SOURCE[1]:-$0}:$line"
}

# run_step <name> <function>: run one step in a subshell with set -e and record
# failures instead of aborting. Not "$@" || ... (that ignores set -e).
run_step() {
    local name="$1"
    shift
    local status

    set +e
    ( set -e; "$@" )
    status=$?
    set -e

    if (( status != 0 )); then
        log_error "Step '$name' failed (exit $status)"
        FAILED_STEPS+=("$name")
    fi
}

ask_for_reboot() {
    if [[ "$SKIP_REBOOT" == true ]] || [[ "$DRY_RUN" == true ]]; then
        log_info "Reboot prompt skipped"
        return 0
    fi

    if confirm "Setup completed. Reboot now?" "N"; then
        log_info "Rebooting system..."
        sudo reboot
    else
        log_info "Reboot cancelled. Remember to reboot for all changes to take effect."
    fi
}
