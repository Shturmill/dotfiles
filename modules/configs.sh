#!/bin/bash

# Configuration Files Copying

copy_configs() {
    if [[ "$SKIP_CONFIGS" == true ]]; then
        log_info "Skipping config file copying"
        return 0
    fi

    log_info "Copying configuration files..."

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would create config target directory: $TARGET_DIR"
    else
        mkdir -p "$TARGET_DIR"
    fi

    local config_dir="$SOURCE_DIR/config"

    if [[ ! -d "$config_dir" ]]; then
        log_warn "Config directory not found: $config_dir"
        return 0
    fi

    # Get list of items inside config/
    local config_items=()
    while IFS= read -r -d '' item; do
        config_items+=("$item")
    done < <(find "$config_dir" -mindepth 1 -maxdepth 1 -print0)

    if [[ ${#config_items[@]} -eq 0 ]]; then
        log_warn "No config files/directories found in $config_dir"
        return 0
    fi

    log_info "Found ${#config_items[@]} config item(s) to copy"

    for item in "${config_items[@]}"; do
        local basename_item=$(basename "$item")
        local target_path="$TARGET_DIR/$basename_item"

        if [[ "$DRY_RUN" == true ]]; then
            create_backup "$target_path"
            if [[ -e "$target_path" ]]; then
                log_debug "DRY-RUN: Would remove existing target $target_path"
            fi
            log_debug "DRY-RUN: Would copy $item -> $target_path"
        else
            if [[ -e "$target_path" ]]; then
                create_backup "$target_path"
                rm -rf "$target_path"
            fi

            if cp -rv "$item" "$target_path"; then
                log_info "Copied: $basename_item"
            else
                log_error "Failed to copy: $basename_item"
            fi
        fi
    done

    if [[ "$DRY_RUN" == true ]]; then
        log_info "DRY-RUN: Configuration files would be copied to $TARGET_DIR"
    else
        log_info "Configuration files copied to $TARGET_DIR"
    fi
}
