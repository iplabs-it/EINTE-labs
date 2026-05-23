#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="${SCRIPT_DIR}/.."

show_help() {
    cat << 'EOF'
HAS Lab - GRAFANA EDITION

Usage:
  ./run_demo.sh build      Build Docker images
  ./run_demo.sh content    Generate DASH video content
  ./run_demo.sh deploy     Deploy lab with Prometheus + Grafana
  ./run_demo.sh start      Start client (with metrics)
  ./run_demo.sh shape      Open shaper shell
  ./run_demo.sh watch      Watch telemetry
  ./run_demo.sh analyze    Analyze telemetry
  ./run_demo.sh destroy    Tear down lab

Monitoring:
  Grafana:    http://localhost:3000 (admin/admin)
  Prometheus: http://localhost:9090
EOF
}

build_images() {
    echo "Building Docker images..."
    docker build -t has-server:latest "${LAB_DIR}/docker/server"
    docker build -t has-client:latest "${LAB_DIR}/docker/client"
    echo "Done!"
}

prepare_content() {
    if [[ ! -f "${LAB_DIR}/content/stream/manifest.mpd" ]]; then
        bash "${SCRIPT_DIR}/prepare_content.sh"
    else
        echo "Content exists, skipping..."
    fi
}

deploy_lab() {
    cd "${LAB_DIR}"
    mkdir -p content/stream logs
    sudo containerlab deploy --topo clab-topology.yaml
    echo ""
    echo "Grafana:    http://localhost:3000 (admin/admin)"
    echo "Prometheus: http://localhost:9090"
}

start_client() {
    CLIENT=$(docker ps --format '{{.Names}}' | grep -E 'has-lab.*client' | head -1)
    [[ -z "$CLIENT" ]] && { echo "Client not found"; exit 1; }
    rm -f "${LAB_DIR}/logs/telemetry.jsonl" 2>/dev/null
    docker exec "$CLIENT" rm -f /app/logs/telemetry.jsonl 2>/dev/null
    echo "Starting client with metrics..."
    echo "Grafana: http://localhost:3000"
    docker exec -it "$CLIENT" python3 /app/dash_client.py --mpd http://10.0.1.2/stream/manifest.mpd --output /app/logs --metrics --loop
}

open_shaper() {
    SHAPER=$(docker ps --format '{{.Names}}' | grep -E 'has-lab.*shaper' | head -1)
    [[ -z "$SHAPER" ]] && { echo "Shaper not found"; exit 1; }
    docker exec -it "$SHAPER" bash -c "cd /tmp && cat > shape_traffic.sh << 'SCRIPT'
$(cat "${SCRIPT_DIR}/shape_traffic.sh")
SCRIPT
chmod +x shape_traffic.sh && bash"
}

watch_telemetry() {
    CLIENT=$(docker ps --format '{{.Names}}' | grep -E 'has-lab.*client' | head -1)
    [[ -z "$CLIENT" ]] && { echo "Client not found"; exit 1; }
    docker exec "$CLIENT" tail -f /app/logs/telemetry.jsonl 2>/dev/null | python3 "${SCRIPT_DIR}/format_telemetry.py"
}

analyze_telemetry() {
    CLIENT=$(docker ps --format '{{.Names}}' | grep -E 'has-lab.*client' | head -1)
    HOST_TELEMETRY="${LAB_DIR}/logs/telemetry.jsonl"
    [[ -n "$CLIENT" ]] && docker cp "$CLIENT:/app/logs/telemetry.jsonl" "$HOST_TELEMETRY" 2>/dev/null || true
    [[ -f "$HOST_TELEMETRY" ]] && python3 "${SCRIPT_DIR}/analyze_telemetry.py" "$HOST_TELEMETRY" || { echo "No telemetry"; exit 1; }
}

destroy_lab() {
    cd "${LAB_DIR}"
    sudo containerlab destroy --topo clab-topology.yaml --cleanup
}

chmod +x "${SCRIPT_DIR}"/*.sh 2>/dev/null || true

case "${1:-}" in
    "build") build_images ;;
    "content") prepare_content ;;
    "deploy") deploy_lab ;;
    "start") start_client ;;
    "shape") open_shaper ;;
    "watch") watch_telemetry ;;
    "analyze") analyze_telemetry ;;
    "destroy") destroy_lab ;;
    "full") build_images; prepare_content; deploy_lab ;;
    *) show_help ;;
esac
