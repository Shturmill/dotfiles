#!/bin/bash

# Dotfiles installer for Arch Linux

set -Eeuo pipefail

# Configuration
readonly SCRIPT_VERSION="2.2"
SOURCE_DIR=$(dirname "$(realpath "$0")")
RUN_ID=$(date +%F_%H-%M-%S)
readonly SOURCE_DIR RUN_ID
readonly TARGET_DIR="$HOME/.config"
readonly LOG_DIR="$HOME/.dotfiles_install_logs"
readonly LOG_FILE="$LOG_DIR/install_$RUN_ID.log"
readonly BACKUP_ROOT="$HOME/.dotfiles_backups"
readonly BACKUP_DIR="$BACKUP_ROOT/$RUN_ID"
# How many install logs and backup runs to keep
readonly KEEP_RUNS=10

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
SKIP_AUR=false
AUR_REQUESTED=false
SKIP_NERDFONTS=false
NO_PKG=false
ASSUME_DEFAULTS=false
FAILED_STEPS=()

# Source library files
# shellcheck source=lib/logging.sh
source "$SOURCE_DIR/lib/logging.sh"
# shellcheck source=lib/utils.sh
source "$SOURCE_DIR/lib/utils.sh"
# shellcheck source=lib/validation.sh
source "$SOURCE_DIR/lib/validation.sh"

# Source module files
# shellcheck source=modules/dependencies.sh
source "$SOURCE_DIR/modules/dependencies.sh"
# shellcheck source=modules/yay.sh
source "$SOURCE_DIR/modules/yay.sh"
# shellcheck source=modules/docker.sh
source "$SOURCE_DIR/modules/docker.sh"
# shellcheck source=modules/nerdfonts.sh
source "$SOURCE_DIR/modules/nerdfonts.sh"
# shellcheck source=modules/firefox.sh
source "$SOURCE_DIR/modules/firefox.sh"
# shellcheck source=modules/shell.sh
source "$SOURCE_DIR/modules/shell.sh"
# shellcheck source=modules/configs.sh
source "$SOURCE_DIR/modules/configs.sh"

trap 'on_error $? $LINENO' ERR

# --- Main Functions ---

print_usage() {
    cat << EOF
Dotfiles Installer v$SCRIPT_VERSION

Usage: $0 [OPTIONS]

OPTIONS:
    -h, --help          Show this help message
    -d, --dry-run       Show what would be done without making changes
    -v, --verbose       Enable verbose output
    --defaults          Answer every question with its default (never reboots)
                        and pass --noconfirm to pacman/yay; required when stdin
                        is not a terminal
    --skip-deps         Skip dependency installation
    --skip-aur          Skip AUR packages (wlogout)
    --skip-yay          Skip yay installation
    --skip-firefox      Skip Firefox setup
    --skip-shell        Skip shell change
    --skip-configs      Skip config file copying
    --skip-docker       Skip Docker installation
    --skip-nerdfonts    Skip Nerd Fonts installation
    --skip-reboot       Skip reboot prompt
    --no-pkg            Skip everything that needs a package manager (deps,
                        yay, Docker); enabled automatically without pacman
    --only-deps         Only install dependencies
    --only-yay          Only install yay
    --only-firefox      Only setup Firefox
    --only-shell        Only change shell
    --only-configs      Only copy configs
    --only-aur          Only install AUR packages (needs yay)
    --only-docker       Only install Docker
    --only-nerdfonts    Only install Nerd Fonts

DOCKER INSTALLATION:
    The Docker setup includes:
    - Installing docker, docker-compose, docker-buildx
    - Creating docker group
    - Optionally adding current user to docker group (root-equivalent,
      asked separately, default no)
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
    $0 --no-pkg             # Configs, Firefox, fonts, shell only
    $0 --defaults --skip-docker  # Unattended run (e.g. in a container)

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
            --defaults)
                ASSUME_DEFAULTS=true
                ;;
            --skip-deps)
                SKIP_DEPS=true
                SKIP_AUR=true
                ;;
            --skip-aur)
                SKIP_AUR=true
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
            --no-pkg)
                NO_PKG=true
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
                SKIP_AUR=true
                SKIP_DEPS=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-firefox)
                SKIP_AUR=true
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-shell)
                SKIP_AUR=true
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-configs)
                SKIP_AUR=true
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-docker)
                SKIP_AUR=true
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-aur)
                AUR_REQUESTED=true
                SKIP_DEPS=true
                SKIP_YAY=true
                SKIP_FIREFOX=true
                SKIP_SHELL=true
                SKIP_CONFIGS=true
                SKIP_DOCKER=true
                SKIP_NERDFONTS=true
                SKIP_REBOOT=true
                ;;
            --only-nerdfonts)
                SKIP_AUR=true
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
    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                print_usage
                exit 0
                ;;
        esac
    done

    echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  Dotfiles Installer v$SCRIPT_VERSION         ║${NC}"
    echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
    echo

    # Before setup_logging: sudo -E would leave a root-owned log dir in $HOME
    # that breaks the next run. Steps call sudo; makepkg needs a real user.
    if (( EUID == 0 )); then
        echo -e "${RED}[ERROR]${NC} Do not run the installer as root or with sudo; run it as your user" >&2
        exit 1
    fi

    setup_logging
    parse_arguments "$@"
    validate_environment

    log_info "Starting installation process..."

    migrate_legacy_backups

    run_step deps install_dependencies
    run_step yay install_yay
    run_step aur install_aur_packages
    run_step docker setup_docker
    run_step nerdfonts setup_nerdfonts
    run_step firefox setup_firefox
    run_step shell change_shell
    run_step configs copy_configs

    if [[ "$DRY_RUN" == false ]]; then
        prune_old "$LOG_DIR" "$KEEP_RUNS" 'install_*.log'
        prune_old "$BACKUP_ROOT" "$KEEP_RUNS" '[0-9]*'
    fi

    if [[ ${#FAILED_STEPS[@]} -eq 0 ]]; then
        log_info "Installation completed successfully!"
    else
        log_warn "Installation finished with failed steps: ${FAILED_STEPS[*]}"
        log_warn "Fix the errors above and re-run that step with --only-<step> (see --help)"
    fi
    log_info "Log file: $LOG_FILE"

    if [[ -d "$BACKUP_DIR" ]]; then
        log_info "Backups saved to: $BACKUP_DIR"
    fi

    ask_for_reboot

    if [[ ${#FAILED_STEPS[@]} -ne 0 ]]; then
        exit 1
    fi
}

# Run main function with all arguments
main "$@"
