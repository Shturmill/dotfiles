#!/bin/bash

# Nerd Fonts Installation

setup_nerdfonts() {
    if [[ "$SKIP_NERDFONTS" == true ]]; then
        log_info "Skipping Nerd Fonts installation (--skip-nerdfonts flag)"
        return 0
    fi

    log_info "Nerd Fonts Setup..."

    echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║       Nerd Fonts Installation         ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"

    if ! confirm "Install Nerd Fonts? (popular programming fonts with icons)" "N"; then
        log_info "Nerd Fonts installation skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would show Nerd Fonts selection and install selected fonts"
        return 0
    fi

    # Available fonts list
    local available_fonts=(
        "JetBrainsMono"
        "FiraCode"
        "Hack"
        "SourceCodePro"
        "UbuntuMono"
        "CascadiaCode"
        "Meslo"
        "RobotoMono"
        "Inconsolata"
        "DejaVuSansMono"
        "IBMPlexMono"
        "Iosevka"
        "VictorMono"
        "DroidSansMono"
        "AnonymousPro"
        "Terminus"
        "Mononoki"
        "Noto"
        "Agave"
        "ComicShannsMono"
    )

    echo
    echo -e "${CYAN}Available Nerd Fonts:${NC}"
    echo -e "${CYAN}────────────────────────────────────────${NC}"

    local col=0
    for i in "${!available_fonts[@]}"; do
        printf "  %2d) %-20s" "$((i+1))" "${available_fonts[$i]}"
        col=$((col + 1))
        if [[ $col -eq 3 ]]; then
            echo
            col=0
        fi
    done
    [[ $col -ne 0 ]] && echo

    echo
    echo -e "  ${GREEN}a)${NC}  Install ALL fonts"
    echo -e "  ${GREEN}p)${NC}  Install popular fonts (JetBrainsMono, FiraCode, Hack, CascadiaCode, Meslo)"
    echo -e "  ${GREEN}q)${NC}  Cancel"
    echo

    local selected_fonts=()

    read -p "Enter your choice (numbers separated by space, 'a' for all, 'p' for popular, 'q' to cancel): " -r choice

    case "$choice" in
        q|Q)
            log_info "Nerd Fonts installation cancelled"
            return 0
            ;;
        a|A)
            selected_fonts=("${available_fonts[@]}")
            ;;
        p|P)
            selected_fonts=("JetBrainsMono" "FiraCode" "Hack" "CascadiaCode" "Meslo")
            ;;
        *)
            # Parse space-separated numbers
            for num in $choice; do
                if [[ "$num" =~ ^[0-9]+$ ]] && [[ "$num" -ge 1 ]] && [[ "$num" -le "${#available_fonts[@]}" ]]; then
                    selected_fonts+=("${available_fonts[$((num-1))]}")
                else
                    log_warn "Invalid selection: $num"
                fi
            done
            ;;
    esac

    if [[ ${#selected_fonts[@]} -eq 0 ]]; then
        log_warn "No fonts selected"
        return 0
    fi

    # Check for required tools
    if ! command -v curl &> /dev/null; then
        log_info "Installing curl..."
        if ! sudo pacman -S --noconfirm curl; then
            log_error "Failed to install curl"
            return 1
        fi
    fi

    if ! command -v unzip &> /dev/null; then
        log_info "Installing unzip..."
        if ! sudo pacman -S --noconfirm unzip; then
            log_error "Failed to install unzip"
            return 1
        fi
    fi

    # Create fonts directory
    mkdir -p "$FONTS_DIR"

    (
        local total=${#selected_fonts[@]}
        local current=0
        local failed_fonts=()
        local temp_root
        temp_root=$(mktemp -d "${TMPDIR:-/tmp}/nerdfonts.XXXXXXXXXX")
        trap 'rm -rf "$temp_root"' EXIT

        echo
        log_info "Installing ${total} font(s)..."
        echo

        for font in "${selected_fonts[@]}"; do
            current=$((current + 1))
            local progress="[$current/$total]"

            log_step "$progress Downloading $font..."

            local font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/${NERD_FONTS_VERSION}/${font}.zip"
            local temp_zip="$temp_root/${font}.zip"
            local temp_dir="$temp_root/${font}_extracted"

            # Download font
            if ! curl -fsSL -o "$temp_zip" "$font_url"; then
                log_error "Failed to download $font"
                failed_fonts+=("$font")
                continue
            fi

            # Create temp directory and extract
            mkdir -p "$temp_dir"
            if ! unzip -q -o "$temp_zip" -d "$temp_dir"; then
                log_error "Failed to extract $font"
                failed_fonts+=("$font")
                continue
            fi

            # Move font files to fonts directory
            find "$temp_dir" -type f \( -name "*.ttf" -o -name "*.otf" \) -exec mv {} "$FONTS_DIR/" \;

            rm -rf "$temp_zip" "$temp_dir"

            log_info "$progress $font installed"
        done

        # Update font cache
        log_step "Updating font cache..."
        if command -v fc-cache &> /dev/null; then
            fc-cache -fv "$FONTS_DIR" > /dev/null 2>&1
            log_info "Font cache updated"
        else
            log_warn "fc-cache not found. You may need to manually refresh font cache."
        fi

        echo
        if [[ ${#failed_fonts[@]} -eq 0 ]]; then
            log_info "All fonts installed successfully!"
        else
            log_warn "Some fonts failed to install: ${failed_fonts[*]}"
        fi

        echo -e "${GREEN}Nerd Fonts Summary:${NC}"
        echo -e "  • Fonts installed: $((total - ${#failed_fonts[@]}))/${total}"
        echo -e "  • Location: $FONTS_DIR"
        echo -e "  • To use: Set your terminal font to one of the installed Nerd Fonts"
        echo

        # Show installed fonts
        if confirm "Show list of installed font files?" "N"; then
            echo -e "${CYAN}Installed fonts in $FONTS_DIR:${NC}"
            ls -1 "$FONTS_DIR"/*.{ttf,otf} 2>/dev/null | head -20
            local font_count=$(ls -1 "$FONTS_DIR"/*.{ttf,otf} 2>/dev/null | wc -l)
            if [[ $font_count -gt 20 ]]; then
                echo "  ... and $((font_count - 20)) more files"
            fi
        fi
    )
}
