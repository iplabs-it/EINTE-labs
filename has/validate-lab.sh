#!/bin/bash
# HAS Lab Validation Script
# Checks that all components are working correctly

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

ERRORS=0
WARNINGS=0

check() {
    local name="$1"
    local command="$2"
    local expected="$3"

    echo -n "Checking ${name}... "

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
        return 0
    else
        echo -e "${RED}✗${NC}"
        if [ -n "$expected" ]; then
            echo "  Expected: $expected"
        fi
        ((ERRORS++))
        return 1
    fi
}

check_warn() {
    local name="$1"
    local command="$2"

    echo -n "Checking ${name}... "

    if eval "$command" &>/dev/null; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠${NC}"
        ((WARNINGS++)) || true
    fi
    return 0
}

echo "======================================"
echo "HAS Lab - Validation"
echo "======================================"
echo ""

# Check containers are running
echo "Container Status:"
check "Server container" "docker ps | grep -q 'Up.*clab-has-lab-server'"
check "Client container" "docker ps | grep -q 'Up.*clab-has-lab-client'"
check "Shaper container" "docker ps | grep -q 'Up.*clab-has-lab-shaper'"
check "Prometheus container" "docker ps | grep -q 'Up.*clab-has-lab-prometheus'"
check "Grafana container" "docker ps | grep -q 'Up.*clab-has-lab-grafana'"
echo ""

# Check network connectivity
echo "Network Connectivity:"
check "Server responds" "docker exec clab-has-lab-client curl -s --max-time 2 http://10.0.1.2/ > /dev/null"
check "DASH manifest available" "docker exec clab-has-lab-client curl -s --max-time 2 http://10.0.1.2/stream/manifest.mpd | grep -q MPD"
echo ""

# Check client metrics
echo "Client Metrics:"
check "Client metrics endpoint" "docker exec clab-has-lab-client curl -s --max-time 2 http://localhost:8000/metrics | grep -q has_"
check "Client is streaming" "docker exec clab-has-lab-client curl -s --max-time 2 http://localhost:8000/metrics | grep -q 'has_segment_number [0-9]'"
echo ""

# Check Prometheus
echo "Prometheus:"
check "Prometheus API" "curl -s --max-time 2 http://localhost:9090/api/v1/status/config | grep -q success"

# Get container IPs for checking
CLIENT_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' clab-has-lab-client 2>/dev/null | head -1)

if [ -n "$CLIENT_IP" ]; then
    check "Prometheus can reach client" "docker exec clab-has-lab-prometheus wget -q -O- -T 2 http://${CLIENT_IP}:8000/metrics 2>&1 | grep -q has_"

    # Check if Prometheus has scraped data
    if curl -s --max-time 2 "http://localhost:9090/api/v1/query?query=has_current_bitrate_kbps" | grep -q '"result":\['; then
        check "Prometheus has metrics data" "curl -s --max-time 2 'http://localhost:9090/api/v1/query?query=has_current_bitrate_kbps' | python3 -c \"import sys,json; d=json.load(sys.stdin); exit(0 if d['data']['result'] else 1)\""
    else
        echo -e "Prometheus scraping metrics... ${YELLOW}⚠ (may take a few seconds)${NC}"
        ((WARNINGS++))
    fi
fi

# Check target status
TARGET_STATUS=$(curl -s --max-time 2 http://localhost:9090/api/v1/targets 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['data']['activeTargets'][0]['health'] if len(d['data']['activeTargets']) > 0 else 'unknown')" 2>/dev/null || echo "unknown")

if [ "$TARGET_STATUS" = "up" ]; then
    echo -e "Prometheus target status... ${GREEN}✓ (up)${NC}"
elif [ "$TARGET_STATUS" = "down" ]; then
    echo -e "Prometheus target status... ${RED}✗ (down)${NC}"
    ((ERRORS++))
else
    echo -e "Prometheus target status... ${YELLOW}⚠ (unknown)${NC}"
    ((WARNINGS++))
fi

echo ""

# Check Grafana
echo "Grafana:"
check "Grafana API" "curl -s --max-time 2 http://admin:admin@localhost:3000/api/health | grep -q ok"
check "Grafana datasource" "curl -s --max-time 2 http://admin:admin@localhost:3000/api/datasources | grep -q Prometheus"
check "Grafana can query Prometheus" "curl -s --max-time 5 'http://admin:admin@localhost:3000/api/datasources/proxy/1/api/v1/query?query=up' | grep -q success"
check "Dashboard exists" "curl -s --max-time 2 http://admin:admin@localhost:3000/api/search?query=HAS | grep -q has-lab"
echo ""

# Check logs for errors
echo "Container Health:"
check_warn "Server no errors" "! docker logs clab-has-lab-server 2>&1 | tail -20 | grep -i 'error\|failed\|critical'"
check_warn "Client no errors" "! docker logs clab-has-lab-client 2>&1 | tail -20 | grep -i 'error\|failed\|critical' | grep -v 'ERROR:' | grep -q ."
check_warn "Prometheus no errors" "! docker logs clab-has-lab-prometheus 2>&1 | tail -20 | grep -i 'level=error'"
check_warn "Grafana no errors" "! docker logs clab-has-lab-grafana 2>&1 | tail -20 | grep -i 'lvl=error'"
echo ""

# Summary
echo "======================================"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo -e "${GREEN}All checks passed!${NC}"
    echo "======================================"
    echo ""
    echo "Your lab is ready to use!"
    echo ""
    echo "Access URLs:"
    echo "  Grafana Dashboard: http://localhost:3000/d/has-lab/has-lab-dashboard"
    echo "  Prometheus:        http://localhost:9090"
    echo ""
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo -e "${YELLOW}Validation completed with ${WARNINGS} warning(s)${NC}"
    echo "======================================"
    echo ""
    echo "Lab is functional but some checks failed."
    echo "This is usually normal for newly deployed labs (metrics need time to collect)."
    echo ""
    exit 0
else
    echo -e "${RED}Validation failed with ${ERRORS} error(s) and ${WARNINGS} warning(s)${NC}"
    echo "======================================"
    echo ""
    echo "Troubleshooting:"
    echo "  1. Check container logs: docker logs clab-has-lab-<container-name>"
    echo "  2. Verify network connectivity: docker exec clab-has-lab-client ping -c 2 10.0.1.2"
    echo "  3. Check Prometheus targets: http://localhost:9090/targets"
    echo "  4. Try restarting monitoring: docker restart clab-has-lab-prometheus clab-has-lab-grafana"
    echo ""
    exit 1
fi
