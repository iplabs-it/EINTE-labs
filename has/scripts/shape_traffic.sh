#!/bin/bash

show_help() {
    cat << 'EOF'
Traffic Shaping Control

Usage:
  ./shape_traffic.sh excellent   10 Mbit/s, 10ms delay
  ./shape_traffic.sh good        5 Mbit/s, 20ms delay
  ./shape_traffic.sh moderate    3 Mbit/s, 50ms delay
  ./shape_traffic.sh poor        1 Mbit/s, 100ms delay
  ./shape_traffic.sh terrible    500 Kbit/s, 200ms delay
  ./shape_traffic.sh scenario    Auto-cycle through conditions
  ./shape_traffic.sh show        Show current settings
EOF
}

apply_shaping() {
    local rate=$1
    local delay=$2
    local name=$3
    tc qdisc del dev eth2 root 2>/dev/null || true
    tc qdisc add dev eth2 root handle 1: htb default 10
    tc class add dev eth2 parent 1: classid 1:10 htb rate $rate ceil $rate
    tc qdisc add dev eth2 parent 1:10 handle 10: netem delay $delay
    echo "Applied: $name ($rate, ${delay} delay)"
}

case "${1:-}" in
    "excellent") apply_shaping "10mbit" "10ms" "Excellent" ;;
    "good")      apply_shaping "5mbit" "20ms" "Good" ;;
    "moderate")  apply_shaping "3mbit" "50ms" "Moderate" ;;
    "poor")      apply_shaping "1mbit" "100ms" "Poor" ;;
    "terrible")  apply_shaping "500kbit" "200ms" "Terrible" ;;
    "scenario")
        echo "Running scenario (Ctrl+C to stop)..."
        while true; do
            apply_shaping "10mbit" "10ms" "Excellent"; sleep 60
            apply_shaping "5mbit" "20ms" "Good"; sleep 60
            apply_shaping "3mbit" "50ms" "Moderate"; sleep 90
            apply_shaping "1mbit" "100ms" "Poor"; sleep 90
            apply_shaping "500kbit" "200ms" "Terrible"; sleep 60
        done
        ;;
    "show")
        tc qdisc show dev eth2
        tc class show dev eth2
        ;;
    *) show_help ;;
esac
