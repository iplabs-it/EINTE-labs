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

# The student index number personalises the lab (see scripts/student-seed.sh).
# It is asked for once and kept here; STUDENT_ID in the environment overrides it.
STUDENT_ID_FILE="$LAB_DIR/.student-id"

# Client sessions are recorded with script(1) into this folder (shared with the
# client container as /home/student/saved/sessions). If LAB_LOG_UPLOAD_URL is
# set, each recording is also uploaded there when the session ends
# (multipart POST with fields student, token, log, timing).
SESSION_DIR="$LAB_DIR/content/saved/sessions"
LAB_LOG_UPLOAD_URL="${LAB_LOG_UPLOAD_URL:-}"

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

# ---- per-student personalisation ----------------------------------------
read_student_id() {
    if [[ -n "${STUDENT_ID:-}" ]]; then
        :
    elif [[ -s "$STUDENT_ID_FILE" ]]; then
        STUDENT_ID="$(tr -d '[:space:]' < "$STUDENT_ID_FILE")"
    else
        if [[ ! -t 0 ]]; then
            print_error "No student index number known. Run: STUDENT_ID=<your number> $0 $1"
            exit 1
        fi
        echo ""
        echo "This lab is personalised with your student index number: some values"
        echo "(API items, cache lifetimes, certificate details, the X-Lab-Token header)"
        echo "depend on it, and your report is checked against them. Enter the number"
        echo "exactly as it appears in your student records."
        while true; do
            read -r -p "Student index number: " STUDENT_ID
            STUDENT_ID="$(printf '%s' "$STUDENT_ID" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')"
            if [[ "$STUDENT_ID" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; then
                break
            fi
            echo "  Please enter 3-32 letters or digits (no spaces)."
        done
        printf '%s\n' "$STUDENT_ID" > "$STUDENT_ID_FILE"
    fi
    if [[ ! "$STUDENT_ID" =~ ^[A-Za-z0-9_.-]{3,32}$ ]]; then
        print_error "Invalid student index number '$STUDENT_ID' (3-32 letters or digits)."
        exit 1
    fi
    eval "$("$LAB_DIR/scripts/student-seed.sh" "$STUDENT_ID")"
    export STUDENT_ID TOKEN CERT_DAYS CERT_SAN
}

personalise_lab() {
    print_step "Personalising the lab for student $STUDENT_ID (token $TOKEN)..."
    bash "$LAB_DIR/scripts/personalise.sh" "$STUDENT_ID" > /dev/null
    echo "  ✓ Generated configs/generated/student.conf and content/generated/index.html"
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
    
    # The certificate carries per-student details; regenerate it when the
    # student (token) changed since the certificates were made.
    if [[ -f "$LAB_DIR/certs/server.crt" && -f "$LAB_DIR/certs/server.key" ]]; then
        if [[ "$(cat "$LAB_DIR/certs/.token" 2>/dev/null)" == "$TOKEN" ]]; then
            print_warn "Certificates already exist. Skipping generation."
            print_warn "  Delete $LAB_DIR/certs/ to regenerate."
            return 0
        fi
        print_warn "Certificates belong to another student token. Regenerating..."
        rm -rf "$LAB_DIR/certs"
    fi
    
    CERT_DAYS="$CERT_DAYS" CERT_SAN="$CERT_SAN" bash "$LAB_DIR/scripts/generate-certs.sh" > /dev/null
    printf '%s\n' "$TOKEN" > "$LAB_DIR/certs/.token"
    echo "  ✓ Certificates generated (valid $CERT_DAYS days, SAN $CERT_SAN)"
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

check_containers() {
    print_step "Checking containers..."

    local node failed=0
    for node in client cache-proxy webserver https-server; do
        if [[ "$(docker inspect -f '{{.State.Running}}' "clab-$LAB_NAME-$node" 2>/dev/null)" != "true" ]]; then
            print_error "Container '$node' is not running."
            failed=1
        fi
    done
    if [[ $failed -eq 1 ]]; then
        print_error "The lab did not start correctly. Run ./bootstrap.sh deploy again."
        exit 1
    fi

    # client-init.sh installs curl, bash etc. from the Internet during deploy;
    # if that failed the client shell is unusable, so retry once and stop
    # with a clear message rather than reporting success.
    if ! docker exec "clab-$LAB_NAME-client" sh -c 'command -v bash && command -v curl' &> /dev/null; then
        print_warn "Client tools are missing (package download failed?). Retrying..."
        docker exec "clab-$LAB_NAME-client" sh /tmp/client-init.sh &> /dev/null || true
        if ! docker exec "clab-$LAB_NAME-client" sh -c 'command -v bash && command -v curl' &> /dev/null; then
            print_error "Could not install the client tools. Check that the VM is online, then run ./bootstrap.sh deploy again."
            exit 1
        fi
    fi

    echo "  ✓ All containers running"
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
    echo "Student:    $STUDENT_ID  (X-Lab-Token: $TOKEN)"
    echo "Recordings: your client sessions are recorded to content/saved/sessions/"
    echo ""
    echo "Available containers:"
    echo "  • client       - Student workstation (curl, openssl, tcpdump)"
    echo "  • cache-proxy  - Caching reverse proxy"
    echo "  • webserver    - HTTP origin server"
    echo "  • https-server - HTTPS/TLS server"
    echo ""
    echo "Quick access:"
    echo "  Connect to client:   ./bootstrap.sh client"
    echo "  View web server:     curl http://localhost:8080/"
    echo "  View HTTPS server:   curl -k https://localhost:8443/"
    echo ""
    echo "From client container:"
    echo "  HTTP via proxy:      curl http://cache-proxy/"
    echo "  HTTP direct:         curl http://webserver/"
    echo "  HTTPS:               curl -k https://https-server/"
    echo ""
    echo "To stop the lab:         ./bootstrap.sh destroy"
    echo "To package your results: ./bootstrap.sh package"
    echo ""
}

# ---- session recording and submission package ---------------------------
record_client_session() {
    mkdir -p "$SESSION_DIR"
    local stamp log timing
    stamp="$(date +%Y%m%d-%H%M%S)"
    log="$SESSION_DIR/session-$stamp.log"
    timing="$SESSION_DIR/session-$stamp.timing"
    {
        echo "# HTTP lab client session"
        echo "# student=$STUDENT_ID token=$TOKEN host=$(hostname) start=$(date -Is)"
    } > "$log"
    echo "Connecting to client container (this session is recorded to content/saved/sessions/)..."
    # bash so the manual's `time (for ... done)` syntax in B4.2 works
    # (busybox ash rejects it). `|| true`: do not let set -e skip the
    # permission fix and the upload below when the student's last command
    # failed.
    script -q -a -e -T "$timing" -c "docker exec -it clab-$LAB_NAME-client bash -l" "$log" || true
    echo "# end=$(date -Is)" >> "$log"
    if [[ -n "$LAB_LOG_UPLOAD_URL" ]]; then
        if curl -sf -m 20 -F "student=$STUDENT_ID" -F "token=$TOKEN" \
                -F "log=@$log" -F "timing=@$timing" "$LAB_LOG_UPLOAD_URL" > /dev/null; then
            echo "  ✓ Session recording uploaded"
        else
            print_warn "Could not upload the session recording (kept locally in content/saved/sessions/)."
        fi
    fi
}

package_submission() {
    local out="$HOME/http-lab-$STUDENT_ID-$(date +%Y%m%d-%H%M).tar.gz"
    print_step "Packaging content/saved (your files and session recordings)..."
    tar -czf "$out" -C "$LAB_DIR/content" saved
    echo "  ✓ $out"
    echo "    Submit this archive together with your report."
}

# Files saved in the client's /home/student/saved are created by root inside
# the container; hand them to the VM user so they can be opened and edited
# on the VM (bind mount: content/saved).
fix_saved_permissions() {
    docker exec "clab-$LAB_NAME-client" chown -R "$(id -u):$(id -g)" /home/student/saved &> /dev/null || true
}

# Main execution
main() {
    print_header
    
    case "${1:-deploy}" in
        deploy)
            check_prerequisites
            read_student_id deploy
            personalise_lab
            generate_certificates
            pull_images
            deploy_lab
            check_containers
            wait_for_services
            print_info
            ;;
        destroy)
            print_step "Destroying lab..."
            fix_saved_permissions
            cd "$LAB_DIR"
            containerlab destroy --topo "$LAB_DIR/http-lab.clab.yml" --cleanup
            echo "  ✓ Lab destroyed"
            ;;
        status)
            print_step "Lab status:"
            containerlab inspect --name "$LAB_NAME" || echo "Lab is not running"
            ;;
        client)
            read_student_id client
            if [[ "$(docker inspect -f '{{.State.Running}}' "clab-$LAB_NAME-client" 2>/dev/null)" != "true" ]]; then
                print_error "The lab is not running. Run ./bootstrap.sh deploy first."
                exit 1
            fi
            record_client_session
            fix_saved_permissions
            ;;
        package)
            read_student_id package
            fix_saved_permissions
            package_submission
            ;;
        *)
            echo "Usage: $0 {deploy|destroy|status|client|package}"
            echo ""
            echo "Commands:"
            echo "  deploy   - Deploy the lab (default)"
            echo "  destroy  - Stop and remove the lab"
            echo "  status   - Show lab status"
            echo "  client   - Connect to client container (session is recorded)"
            echo "  package  - Archive your saved files and session recordings for submission"
            exit 1
            ;;
    esac
}

main "$@"
