#!/bin/bash

# Improved dotfiles installer for Arch Linux

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="2.0"
readonly SOURCE_DIR=$(dirname "$(realpath "$0")")
readonly TARGET_DIR="$HOME/.config"
readonly LOG_DIR="$HOME/.dotfiles_install_logs"
readonly LOG_FILE="$LOG_DIR/install_$(date +%F_%H-%M-%S).log"
readonly BACKUP_DIR="$HOME/.dotfiles_backups/$(date +%F_%H-%M-%S)"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Flags
DRY_RUN=false
VERBOSE=false
SKIP_DEPS=false
SKIP_YAY=false
SKIP_FIREFOX=false
SKIP_SHELL=false
SKIP_CONFIGS=false
SKIP_REBOOT=false

# Logging Functions

setup_logging() {
    mkdir -p "$LOG_DIR"
    exec 1> >(tee -a "$LOG_FILE")
    exec 2>&1
    log_info "Installation started at $(date)"
    log_info "Script version: $SCRIPT_VERSION"
    log_info "Source directory: $SOURCE_DIR"
}

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" | tee -a "$LOG_FILE" >&2
}

log_debug() {
    if [[ "$VERBOSE" == true ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1" | tee -a "$LOG_FILE"
    fi
}

# Validation Functions

validate_environment() {
    log_info "Validating environment..."
    
    # Check if running on Arch-based system
    if [[ ! -f /etc/arch-release ]]; then
        log_warn "Not running on Arch Linux. Some features may not work."
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
    if [[ ! -d "$SOURCE_DIR/config" ]] && ! compgen -G "$SOURCE_DIR/config*" > /dev/null; then
        log_warn "No config directories found. Config copying will be skipped."
        SKIP_CONFIGS=true
    fi
    
    log_info "Environment validation completed"
}

# --- Utility Functions ---

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
        mkdir -p "$BACKUP_DIR"
        local backup_path="$BACKUP_DIR/$(basename "$file").$(date +%s)"
        
        if [[ "$DRY_RUN" == true ]]; then
            log_debug "DRY-RUN: Would backup $file to $backup_path"
        else
            cp -a "$file" "$backup_path"
            log_info "Backed up: $file -> $backup_path"
        fi
    fi
}

is_process_running() {
    local process_name="$1"
    pgrep -x "$process_name" > /dev/null 2>&1
}

# --- Installation Functions ---

install_dependencies() {
    if [[ "$SKIP_DEPS" == true ]]; then
        log_info "Skipping dependency installation (--skip-deps flag)"
        return 0
    fi
    
    log_info "Checking dependencies..."
    
    if ! command -v pacman &> /dev/null; then
        log_error "pacman not found. This script requires Arch Linux."
        exit 1
    fi
    
    local packages=(
        "git"
        "firefox"
        "chromium"
        "telegram-desktop"
        "fish"
        "waybar"
        "docker"
        "docker-compose"
        "fastfetch"
        "brightnessctl"
        "power-profiles-daemon"
        "hyprshot"
        "hyprlock"
    )
    
    if ! confirm "Install recommended packages (${packages[*]})?"; then
        log_info "Package installation skipped by user"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would install packages: ${packages[*]}"
        return 0
    fi
    
    log_info "Installing packages..."
    if sudo pacman -Syu --noconfirm --needed "${packages[@]}"; then
        log_info "Packages installed successfully"
    else
        log_error "Failed to install some packages"
        return 1
    fi
}

install_yay() {
    if [[ "$SKIP_YAY" == true ]]; then
        log_info "Skipping yay installation (--skip-yay flag)"
        return 0
    fi
    
    log_info "Checking yay AUR helper..."
    
    if command -v yay &> /dev/null; then
        log_info "yay is already installed"
        return 0
    fi
    
    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would install yay"
        return 0
    fi
    
    log_info "Installing build dependencies for yay..."
    sudo pacman -S --noconfirm --needed git base-devel
    
    local yay_dir="/tmp/yay-install-$$"
    
    log_info "Cloning yay repository..."
    if ! git clone https://aur.archlinux.org/yay.git "$yay_dir"; then
        log_error "Failed to clone yay repository"
        return 1
    fi
    
    log_info "Building and installing yay..."
    (
        cd "$yay_dir"
        if makepkg -si --noconfirm; then
            log_info "yay installed successfully"
        else
            log_error "Failed to build/install yay"
            return 1
        fi
    )
    
    rm -rf "$yay_dir"
}

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

copy_configs() {
    if [[ "$SKIP_CONFIGS" == true ]]; then
        log_info "Skipping config file copying"
        return 0
    fi
    
    log_info "Copying configuration files..."
    
    mkdir -p "$TARGET_DIR"
    
    # Find all config directories/files
    local config_items=()
    while IFS= read -r -d '' item; do
        config_items+=("$item")
    done < <(find "$SOURCE_DIR" -maxdepth 1 -name 'config*' -print0)
    
    if [[ ${#config_items[@]} -eq 0 ]]; then
        log_warn "No config files/directories found"
        return 0
    fi
    
    log_info "Found ${#config_items[@]} config item(s) to copy"
    
    for item in "${config_items[@]}"; do
        local basename_item=$(basename "$item")
        local target_path="$TARGET_DIR/$basename_item"
        
        if [[ -e "$target_path" ]]; then
            create_backup "$target_path"
        fi
        
        if [[ "$DRY_RUN" == true ]]; then
            log_debug "DRY-RUN: Would copy $item -> $target_path"
        else
            if cp -rv "$item" "$TARGET_DIR/"; then
                log_info "Copied: $basename_item"
            else
                log_error "Failed to copy: $basename_item"
            fi
        fi
    done
    
    log_info "Configuration files copied to $TARGET_DIR"
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

# --- Main Functions ---

print_usage() {
    cat << EOF
Dotfiles Installer v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Show what would be done without making changes
    -v, --verbose       Enable verbose output
    --skip-deps         Skip dependency installation
    --skip-yay          Skip yay installation
    --skip-firefox      Skip Firefox setup
    --skip-shell        Skip shell change
    --skip-configs      Skip config file copying
    --skip-reboot       Skip reboot prompt
    --only-deps         Only install dependencies
    --only-yay          Only install yay
    --only-firefox      Only setup Firefox
    --only-shell        Only change shell
    --only-configs      Only copy configs

EXAMPLES:
    $0                      # Full installation
    $0 --dry-run            # Preview changes
    $0 --only-firefox       # Only setup Firefox
    $0 --skip-deps          # Skip dependency installation

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                print_usage
                exit 0
                ;;
            -d|--dry-run)
                DRY_RUN=true
                log_info "DRY-RUN mode enabled"
                ;;
            -v|--verbose)
                VERBOSE=true
                ;;
            --skip-deps)
                SKIP_DEPS=true
                ;;
            --skip-yay)
                SKIP_YAY=true
                ;;
            --skip-firefox)
                SKIP_FIREFOX=true
                ;;
            --skip-shell)
                SKIP_SHELL=true
                ;;
            --skip-configs)
                SKIP_CONFIGS=true
                ;;
            --skip-reboot)
                SKIP_REBOOT=true
                ;;
            --only-deps)
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_REBOOT=true
                ;;
            --only-yay)
                SKIP_DEPS=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_REBOOT=true
                ;;
            --only-firefox)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_REBOOT=true
                ;;
            --only-shell)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_CONFIGS=true
                SKIP_REBOOT=true
                ;;
            --only-configs)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_REBOOT=true
                ;;
            *)
                log_error "Unknown option: $1"
                print_usage
                exit 1
                ;;
        esac
        shift
    done
}

main() {
    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Dotfiles Installer v$SCRIPT_VERSION         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo
    
    parse_arguments "$@"
    setup_logging
    validate_environment
    
    log_info "Starting installation process..."
    
    install_dependencies
    install_yay
    setup_firefox
    change_shell
    copy_configs
    
    log_info "Installation completed successfully!"
    log_info "Log file: $LOG_FILE"
    
    if [[ -d "$BACKUP_DIR" ]] && [[ "$(ls -A "$BACKUP_DIR" 2>/dev/null)" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi
    
    ask_for_reboot
}

# Run main function with all arguments
main "$@"