#!/bin/bash
set -e

echo "=============================================="
echo "  HAS Lab Bootstrap - GRAFANA EDITION"
echo "=============================================="

[[ $EUID -ne 0 ]] && { echo "Run as root (sudo)"; exit 1; }

if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$ID
else
    echo "Cannot detect OS"; exit 1
fi

echo "Detected: $OS $VERSION_ID"

# Install Docker
if ! command -v docker &> /dev/null; then
    echo "Installing Docker..."
    apt-get update -qq
    apt-get install -y -qq ca-certificates curl gnupg
    install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/$OS/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    chmod a+r /etc/apt/keyrings/docker.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/$OS $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    apt-get update -qq
    apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin
fi

systemctl start docker
systemctl enable docker

[[ -n "$SUDO_USER" ]] && usermod -aG docker "$SUDO_USER"

# Install ContainerLab
if ! command -v containerlab &> /dev/null; then
    echo "Installing ContainerLab..."
    bash -c "$(curl -sL https://get.containerlab.dev)"
fi

# Pull images
echo "Pulling Docker images..."
docker pull linuxserver/ffmpeg:latest &
docker pull nginx:alpine &
docker pull python:3.11-alpine &
docker pull ghcr.io/hellt/network-multitool:latest &
docker pull prom/prometheus:latest &
docker pull grafana/grafana:latest &
wait

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
chmod +x "${SCRIPT_DIR}/scripts/"*.sh 2>/dev/null || true

echo ""
echo "=============================================="
echo "  Bootstrap Complete!"
echo "=============================================="
echo "Log out and back in, then:"
echo "  ./scripts/run_demo.sh build"
echo "  ./scripts/run_demo.sh content"
echo "  ./scripts/run_demo.sh deploy"
echo ""
echo "Grafana: http://localhost:3000 (admin/admin)"
