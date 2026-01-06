#!/bin/bash

# Improved dotfiles installer for Arch Linux

set -euo pipefail

# Configuration
readonly SCRIPT_VERSION="2.1"
readonly SOURCE_DIR=$(dirname "$(realpath "$0")")
readonly TARGET_DIR="$HOME/.config"
readonly LOG_DIR="$HOME/.dotfiles_install_logs"
readonly LOG_FILE="$LOG_DIR/install_$(date +%F_%H-%M-%S).log"
readonly BACKUP_DIR="$HOME/.dotfiles_backups/$(date +%F_%H-%M-%S)"

# Nerd Fonts configuration
readonly NERD_FONTS_VERSION="v3.3.0"
readonly FONTS_DIR="$HOME/.local/share/fonts"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly CYAN='\033[0;36m'
readonly MAGENTA='\033[0;35m'
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
SKIP_DOCKER=false
SKIP_NERDFONTS=false

# Source library files
source "$SOURCE_DIR/lib/logging.sh"
source "$SOURCE_DIR/lib/utils.sh"
source "$SOURCE_DIR/lib/validation.sh"

# Source module files
source "$SOURCE_DIR/modules/dependencies.sh"
source "$SOURCE_DIR/modules/yay.sh"
source "$SOURCE_DIR/modules/docker.sh"
source "$SOURCE_DIR/modules/nerdfonts.sh"
source "$SOURCE_DIR/modules/firefox.sh"
source "$SOURCE_DIR/modules/shell.sh"
source "$SOURCE_DIR/modules/configs.sh"

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
    --skip-docker       Skip Docker installation
    --skip-nerdfonts    Skip Nerd Fonts installation
    --skip-reboot       Skip reboot prompt
    --only-deps         Only install dependencies
    --only-yay          Only install yay
    --only-firefox      Only setup Firefox
    --only-shell        Only change shell
    --only-configs      Only copy configs
    --only-docker       Only install Docker
    --only-nerdfonts    Only install Nerd Fonts

DOCKER INSTALLATION:
    The Docker setup includes:
    - Installing docker, docker-compose, docker-buildx
    - Creating docker group
    - Adding current user to docker group
    - Enabling and starting docker.service
    - Configuring Docker daemon with recommended settings
    - Optional hello-world test

NERD FONTS:
    Install popular programming fonts with icons/glyphs.
    Supports individual font selection or batch installation.
    Fonts are installed to ~/.local/share/fonts

EXAMPLES:
    $0                      # Full installation
    $0 --dry-run            # Preview changes
    $0 --only-docker        # Only install Docker
    $0 --only-nerdfonts     # Only install Nerd Fonts
    $0 --skip-docker        # Skip Docker installation
    $0 --only-firefox       # Only setup Firefox

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
            --skip-docker)
                SKIP_DOCKER=true
                ;;
            --skip-nerdfonts)
                SKIP_NERDFONTS=true
                ;;
            --skip-reboot)
                SKIP_REBOOT=true
                ;;
            --only-deps)
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-yay)
                SKIP_DEPS=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-firefox)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-shell)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-configs)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-docker)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-nerdfonts)
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
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
    setup_docker
    setup_nerdfonts
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
