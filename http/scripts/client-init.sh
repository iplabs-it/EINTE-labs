#!/bin/sh
# Client container initialization script
# Installs tools needed for HTTP/HTTPS lab exercises

echo "=== Initializing HTTP Lab Client ==="

# Update and install packages
apk update
apk add --no-cache \
    bash \
    curl \
    wget \
    openssl \
    tcpdump \
    bind-tools \
    jq \
    netcat-openbsd \
    ca-certificates \
    vim \
    less

# Create student working directory
mkdir -p /home/student/saved
mkdir -p /home/student/captures

# Install lab CA into the client trust store so curl can verify the
# https-server cert without -k. Cert is bind-mounted from the host at
# /lab-certs (read-only).
if [ -f /lab-certs/ca.crt ]; then
    cp /lab-certs/ca.crt /usr/local/share/ca-certificates/itlabs-root-ca.crt
    update-ca-certificates >/dev/null 2>&1 || true
fi

# Create helpful aliases and functions
cat > /etc/profile.d/lab-helpers.sh << 'EOF'
# Lab helper aliases
alias ll='ls -la'
alias headers='curl -sI'
alias get='curl -s'
alias getv='curl -v'
alias post='curl -s -X POST'
alias tcpdump-http='tcpdump -i any -A -s 0 port 80'
alias tcpdump-https='tcpdump -i any -s 0 port 443'

# Quick functions for the lab.
# NOTE: function names use underscores (not hyphens) so they parse
# correctly under POSIX sh / busybox ash as well as bash.
webserver() {
    curl -s "http://webserver$1"
}

proxy() {
    curl -s "http://cache-proxy$1"
}

secure() {
    curl -s "https://https-server$1"
}

# Show cache status
cache_test() {
    echo "=== Request 1 ==="
    curl -sI "http://cache-proxy$1" | grep -E "(X-Cache|Cache-Control|ETag|Age)"
    echo ""
    echo "=== Request 2 (should be cached) ==="
    curl -sI "http://cache-proxy$1" | grep -E "(X-Cache|Cache-Control|ETag|Age)"
}

# TLS info
tls_info() {
    echo | openssl s_client -connect "${1:-https-server}:443" 2>/dev/null | openssl x509 -noout -text
}

tls_handshake() {
    echo | openssl s_client -connect "${1:-https-server}:443" -state 2>&1 | grep -E "(SSL_connect|Protocol|Cipher)"
}

# Welcome message
echo ""
echo "╔════════════════════════════════════════════════════════════╗"
echo "║           HTTP Protocol Lab - Client Terminal              ║"
echo "╠════════════════════════════════════════════════════════════╣"
echo "║  Servers:                                                  ║"
echo "║    webserver    - HTTP origin server (port 80)             ║"
echo "║    cache-proxy  - Caching proxy (port 80)                  ║"
echo "║    https-server - HTTPS server (port 443)                  ║"
echo "║                                                            ║"
echo "║  Quick commands:                                           ║"
echo "║    webserver /path   - GET from origin                     ║"
echo "║    proxy /path       - GET via cache proxy                 ║"
echo "║    secure /path      - GET from HTTPS server               ║"
echo "║    cache_test /path  - Test caching behavior               ║"
echo "║    tls_info          - Show TLS certificate                ║"
echo "║    tls_handshake     - Show TLS handshake                  ║"
echo "║                                                            ║"
echo "║  Working directory: /home/student                          ║"
echo "╚════════════════════════════════════════════════════════════╝"
echo ""
EOF

# Add hosts entries for convenience
echo "# Lab hosts" >> /etc/hosts

echo "=== Client initialization complete ==="
