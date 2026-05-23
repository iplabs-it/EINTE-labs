#!/bin/bash
# HAS Lab Setup Script
# This script prepares the environment for lab deployment

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "======================================"
echo "HAS Lab - Setup & Deployment"
echo "======================================"
echo ""

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if running as root for containerlab commands
check_sudo() {
    if ! sudo -n true 2>/dev/null; then
        echo -e "${YELLOW}Note: This script requires sudo access for containerlab${NC}"
        sudo -v
    fi
}

# Check prerequisites
check_prerequisites() {
    echo "Checking prerequisites..."

    local missing=()

    if ! command -v docker &> /dev/null; then
        missing+=("docker")
    fi

    if ! command -v containerlab &> /dev/null && ! command -v clab &> /dev/null; then
        missing+=("containerlab")
    fi

    if ! command -v python3 &> /dev/null; then
        missing+=("python3")
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        echo -e "${RED}ERROR: Missing required tools: ${missing[*]}${NC}"
        echo ""
        echo "Install instructions:"
        echo "  Docker: https://docs.docker.com/engine/install/"
        echo "  Containerlab: https://containerlab.dev/install/"
        echo "  Python3: apt-get install python3 (Debian/Ubuntu) or yum install python3 (RHEL/CentOS)"
        exit 1
    fi

    # Check Docker daemon is running
    if ! docker ps &> /dev/null; then
        echo -e "${RED}ERROR: Docker daemon is not running${NC}"
        exit 1
    fi

    echo -e "${GREEN}✓ All prerequisites met${NC}"
}

# Fix file permissions
fix_permissions() {
    echo "Fixing file permissions for monitoring configs..."

    # Make monitoring configs readable by all users (required for Docker containers)
    chmod -R o+r monitoring/ 2>/dev/null || true
    find monitoring/ -type d -exec chmod o+rx {} \; 2>/dev/null || true

    # Make scripts executable
    chmod +x scripts/*.sh 2>/dev/null || true
    chmod +x *.sh 2>/dev/null || true

    echo -e "${GREEN}✓ Permissions fixed${NC}"
}

# Build Docker images
build_images() {
    echo "Building Docker images..."

    if docker images | grep -q "has-server.*latest" && docker images | grep -q "has-client.*latest"; then
        read -p "Docker images already exist. Rebuild? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Skipping image build"
            return
        fi
    fi

    docker build -t has-server:latest docker/server
    docker build -t has-client:latest docker/client

    echo -e "${GREEN}✓ Images built${NC}"
}

# Prepare content
prepare_content() {
    echo "Preparing DASH video content..."

    if [ -f "content/stream/manifest.mpd" ]; then
        echo "Content already exists, skipping..."
        return
    fi

    if [ ! -f "scripts/prepare_content.sh" ]; then
        echo -e "${YELLOW}Warning: prepare_content.sh not found, skipping content generation${NC}"
        echo "You may need to provide DASH content manually in content/stream/"
        return
    fi

    bash scripts/prepare_content.sh
    echo -e "${GREEN}✓ Content prepared${NC}"
}

# Create necessary directories
create_directories() {
    echo "Creating directories..."
    mkdir -p content/stream logs
    echo -e "${GREEN}✓ Directories created${NC}"
}

# Deploy lab
deploy_lab() {
    echo "Deploying containerlab topology..."

    # Check if lab is already deployed
    if sudo containerlab inspect --topo clab-topology.yaml &>/dev/null; then
        echo -e "${YELLOW}Lab already deployed${NC}"
        read -p "Redeploy? This will destroy and recreate the lab (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo "Destroying existing lab..."
            sudo containerlab destroy --topo clab-topology.yaml --cleanup
            sleep 2
        else
            echo "Keeping existing deployment"
            return
        fi
    fi

    sudo containerlab deploy --topo clab-topology.yaml
    echo -e "${GREEN}✓ Lab deployed${NC}"
}

# Configure monitoring network
configure_monitoring() {
    echo "Configuring monitoring network..."

    # Wait for containers to be fully ready
    sleep 3

    # Get actual container IPs from the management network
    CLIENT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clab-has-lab-client 2>/dev/null | head -1)
    PROMETHEUS_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clab-has-lab-prometheus 2>/dev/null | head -1)

    if [ -z "$CLIENT_IP" ] || [ -z "$PROMETHEUS_IP" ]; then
        echo -e "${RED}ERROR: Could not get container IPs${NC}"
        return 1
    fi

    echo "  Client IP: $CLIENT_IP"
    echo "  Prometheus IP: $PROMETHEUS_IP"

    # Update Prometheus config with actual client IP
    sed -i.bak "s/targets: \['[^']*'\]/targets: ['${CLIENT_IP}:8000']/" monitoring/prometheus/prometheus.yml

    # Update Grafana datasource with actual Prometheus IP
    sed -i.bak "s|url: http://[0-9.]*:9090|url: http://${PROMETHEUS_IP}:9090|" monitoring/grafana/provisioning/datasources/prometheus.yml

    # Restart containers to pick up new config
    echo "Restarting monitoring containers..."
    docker restart clab-has-lab-prometheus clab-has-lab-grafana

    sleep 5

    echo -e "${GREEN}✓ Monitoring configured${NC}"
}

# Main execution
main() {
    check_sudo
    check_prerequisites
    fix_permissions
    create_directories

    echo ""
    read -p "Build Docker images? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        build_images
    fi

    echo ""
    read -p "Prepare video content? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        prepare_content
    fi

    echo ""
    deploy_lab

    echo ""
    configure_monitoring

    echo ""
    echo "======================================"
    echo -e "${GREEN}Setup Complete!${NC}"
    echo "======================================"
    echo ""
    echo "Running validation checks..."
    echo ""

    # Run validation
    if [ -f "./validate-lab.sh" ]; then
        bash ./validate-lab.sh
    fi

    echo ""
    echo "Access your lab:"
    echo "  Grafana:    http://localhost:3000 (admin/admin)"
    echo "  Dashboard:  http://localhost:3000/d/has-lab/has-lab-dashboard"
    echo "  Prometheus: http://localhost:9090"
    echo ""
    echo "Next steps:"
    echo "  ./scripts/run_demo.sh shape   # Shape traffic"
    echo "  ./scripts/run_demo.sh watch   # Watch telemetry"
    echo "  ./scripts/run_demo.sh analyze # Analyze results"
    echo ""
}

main "$@"
