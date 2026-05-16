#!/bin/bash
#===============================================================================
# HTTP Protocol Lab - Bootstrap Script
# Warsaw University of Technology - Institute of Telecommunications
#
# This script prepares and deploys the HTTP lab environment using ContainerLab
#===============================================================================

set -e

LAB_DIR="$(cd "$(dirname "$0")" && pwd)"
LAB_NAME="http-lab"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                   HTTP Protocol Lab                              ║"
    echo "║          Warsaw University of Technology                         ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "${GREEN}[STEP]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_prerequisites() {
    print_step "Checking prerequisites..."
    
    # Check for containerlab
    if ! command -v containerlab &> /dev/null; then
        print_error "ContainerLab is not installed. Please install it first."
        echo "  Installation: https://containerlab.dev/install/"
        exit 1
    fi
    
    # Check for Docker
    if ! command -v docker &> /dev/null; then
        print_error "Docker is not installed. Please install it first."
        exit 1
    fi
    
    # Check if Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    
    # Check for openssl (needed for certificate generation)
    if ! command -v openssl &> /dev/null; then
        print_error "OpenSSL is not installed. Please install it first."
        exit 1
    fi
    
    echo "  ✓ All prerequisites satisfied"
}

generate_certificates() {
    print_step "Generating TLS certificates..."
    
    if [[ -f "$LAB_DIR/certs/server.crt" && -f "$LAB_DIR/certs/server.key" ]]; then
        print_warn "Certificates already exist. Skipping generation."
        print_warn "  Delete $LAB_DIR/certs/ to regenerate."
        return 0
    fi
    
    bash "$LAB_DIR/scripts/generate-certs.sh"
    echo "  ✓ Certificates generated"
}

pull_images() {
    print_step "Pulling required Docker images..."
    
    docker pull alpine:3.19 &> /dev/null || true
    docker pull nginx:alpine &> /dev/null || true
    
    echo "  ✓ Images ready"
}

deploy_lab() {
    print_step "Deploying lab with ContainerLab..."
    
    cd "$LAB_DIR"
    
    # Check if lab is already running
    if containerlab inspect --name "$LAB_NAME" &> /dev/null 2>&1; then
        print_warn "Lab is already running. Destroying old instance..."
        containerlab destroy --topo "$LAB_DIR/http-lab.clab.yml" --cleanup 2>/dev/null || true
        sleep 2
    fi
    
    # Deploy. containerlab runs rootless on the lab VMs (members of the
    # `clab_admins` group); no sudo is required.
    containerlab deploy --topo "$LAB_DIR/http-lab.clab.yml"
    
    echo "  ✓ Lab deployed"
}

wait_for_services() {
    print_step "Waiting for services to start..."
    
    local max_attempts=30
    local attempt=0
    
    while [[ $attempt -lt $max_attempts ]]; do
        if docker exec clab-http-lab-webserver curl -s http://localhost/ &> /dev/null; then
            echo "  ✓ Web server is ready"
            break
        fi
        attempt=$((attempt + 1))
        sleep 1
    done
    
    if [[ $attempt -eq $max_attempts ]]; then
        print_warn "Services may still be starting. Please wait a moment."
    fi
}

print_info() {
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}                    Lab Successfully Deployed!                       ${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "Available containers:"
    echo "  • client       - Student workstation (curl, openssl, tcpdump)"
    echo "  • cache-proxy  - Caching reverse proxy"
    echo "  • webserver    - HTTP origin server"
    echo "  • https-server - HTTPS/TLS server"
    echo ""
    echo "Quick access:"
    echo "  Connect to client:   docker exec -it clab-http-lab-client sh"
    echo "  View web server:     curl http://localhost:8080/"
    echo "  View HTTPS server:   curl -k https://localhost:8443/"
    echo ""
    echo "From client container:"
    echo "  HTTP via proxy:      curl http://cache-proxy/"
    echo "  HTTP direct:         curl http://webserver/"
    echo "  HTTPS:               curl -k https://https-server/"
    echo ""
    echo "To stop the lab:"
    echo "  containerlab destroy --topo $LAB_DIR/http-lab.clab.yml"
    echo ""
}

# Main execution
main() {
    print_header
    
    case "${1:-deploy}" in
        deploy)
            check_prerequisites
            generate_certificates
            pull_images
            deploy_lab
            wait_for_services
            print_info
            ;;
        destroy)
            print_step "Destroying lab..."
            cd "$LAB_DIR"
            containerlab destroy --topo "$LAB_DIR/http-lab.clab.yml" --cleanup
            echo "  ✓ Lab destroyed"
            ;;
        status)
            print_step "Lab status:"
            containerlab inspect --name "$LAB_NAME" || echo "Lab is not running"
            ;;
        client)
            echo "Connecting to client container..."
            # bash so the manual's `time (for ... done)` syntax in B4.2
            # works (busybox ash rejects it as a syntax error).
            docker exec -it clab-http-lab-client bash -l
            ;;
        *)
            echo "Usage: $0 {deploy|destroy|status|client}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the lab (default)"
            echo "  destroy  - Stop and remove the lab"
            echo "  status   - Show lab status"
            echo "  client   - Connect to client container"
            exit 1
            ;;
    esac
}

main "$@"
