# shellcheck shell=bash

# Docker Installation and Configuration

setup_docker() {
    if [[ "$SKIP_DOCKER" == true ]]; then
        log_info "Skipping Docker setup (--skip-docker flag)"
        return 0
    fi

    log_info "Setting up Docker..."

    echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║         Docker Installation           ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"

    if ! confirm "Install and configure Docker?" "N"; then
        log_info "Docker installation skipped by user"
        return 0
    fi

    if [[ "$DRY_RUN" == true ]]; then
        log_debug "DRY-RUN: Would install and configure Docker"
        return 0
    fi

    # Install Docker packages
    log_step "Installing Docker packages..."
    local docker_packages=(
        "docker"
        "docker-compose"
        "docker-buildx"
    )

    if ! sudo pacman -S --noconfirm --needed "${docker_packages[@]}"; then
        log_error "Failed to install Docker packages"
        return 1
    fi
    log_info "Docker packages installed"

    # Create docker group if missing
    log_step "Configuring docker group..."
    if ! getent group docker > /dev/null 2>&1; then
        sudo groupadd docker
        log_info "Docker group created"
    else
        log_info "Docker group already exists"
    fi

    # Add current user to docker group
    log_step "Docker group membership..."
    if id -nG "$USER" | grep -qw "docker"; then
        log_info "User '$USER' is already in docker group"
    else
        log_warn "Members of the docker group can mount / into a container and become root without a password."
        log_warn "Without it use 'sudo docker', or rootless Docker: https://docs.docker.com/engine/security/rootless/"
        if confirm "Add '$USER' to the docker group anyway?" "N"; then
            sudo usermod -aG docker "$USER"
            log_info "User '$USER' added to docker group"
            log_warn "You need to log out and back in for group changes to take effect"
            log_warn "Or run: newgrp docker"
        else
            log_info "User '$USER' not added to docker group"
        fi
    fi

    # docker.service pulls in containerd itself
    log_step "Enabling and starting Docker service..."
    if ! sudo systemctl enable --now docker.service; then
        log_error "Failed to enable/start Docker service"
        return 1
    fi
    log_info "Docker service enabled and started"

    # Configure Docker daemon
    log_step "Configuring Docker daemon..."
    local docker_config_dir="/etc/docker"
    local docker_config_file="$docker_config_dir/daemon.json"

    if [[ ! -f "$docker_config_file" ]]; then
        if confirm "Create Docker daemon configuration with recommended settings?"; then
            sudo mkdir -p "$docker_config_dir"

            sudo tee "$docker_config_file" > /dev/null << 'EOF'
{
    "log-driver": "json-file",
    "log-opts": {
        "max-size": "10m",
        "max-file": "3"
    },
    "storage-driver": "overlay2",
    "live-restore": true,
    "default-address-pools": [
        {
            "base": "172.17.0.0/16",
            "size": 24
        }
    ]
}
EOF
            log_info "Docker daemon configuration created"

            log_step "Restarting Docker to apply configuration..."
            sudo systemctl restart docker.service
            log_info "Docker restarted with new configuration"
        fi
    else
        log_info "Docker daemon configuration already exists"
    fi

    # Verify Docker installation
    log_step "Verifying Docker installation..."

    if docker --version; then
        log_info "Docker CLI is working"
    else
        log_error "Docker CLI check failed"
        return 1
    fi

    # Check Docker Compose version
    if docker compose version; then
        log_info "Docker Compose is working"
    else
        log_warn "Docker Compose check failed"
    fi

    # Check Docker daemon is running
    if sudo docker info > /dev/null 2>&1; then
        log_info "Docker daemon is running"
    else
        log_error "Docker daemon is not running properly"
        return 1
    fi

    # Test Docker
    if confirm "Run Docker hello-world test?"; then
        log_step "Running Docker hello-world test..."
        if sudo docker run --rm hello-world; then
            log_info "Docker is working correctly!"
            sudo docker rmi hello-world > /dev/null 2>&1 || true
        else
            log_warn "Docker test failed. You may need to reboot."
        fi
    fi

    echo
    log_info "Docker installation completed!"
    echo -e "${GREEN}Docker Summary:${NC}"
    echo -e "  • Docker version: $(docker --version | cut -d' ' -f3 | tr -d ',')"
    echo -e "  • Docker Compose: $(docker compose version --short 2>/dev/null || echo 'N/A')"
    echo -e "  • Service status: $(systemctl is-active docker.service)"
    echo -e "  • User in docker group: $(id -nG "$USER" | grep -qw docker && echo 'Yes' || echo 'No (use sudo docker)')"
    echo

    # `id -nG $USER` reads the group database; `id -nG` only this session
    if id -nG "$USER" | grep -qw "docker" && ! id -nG | grep -qw "docker"; then
        echo -e "${YELLOW}Important: Log out and back in to use Docker without sudo${NC}"
        echo -e "${YELLOW}Or run: newgrp docker${NC}"
    fi
}
