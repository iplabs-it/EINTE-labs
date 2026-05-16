#!/bin/bash
# Certificate generation script for HTTP Lab
# Run this BEFORE deploying the lab with containerlab

CERT_DIR="$(dirname "$0")/../certs"
mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

echo "=== Generating TLS certificates for HTTP Lab ==="

# Generate CA private key
echo "[1/5] Generating CA private key..."
openssl genrsa -out ca.key 4096

# Generate CA certificate
echo "[2/5] Generating CA certificate..."
openssl req -x509 -new -nodes -key ca.key -sha256 -days 365 \
    -out ca.crt \
    -subj "/C=PL/ST=Mazovia/L=Warsaw/O=ITLabs/OU=Education/CN=ITLabs Root CA"

# Generate server private key
echo "[3/5] Generating server private key..."
openssl genrsa -out server.key 2048

# Generate server CSR
echo "[4/5] Generating server CSR..."
openssl req -new -key server.key \
    -out server.csr \
    -subj "/C=PL/ST=Mazovia/L=Warsaw/O=ITLabs/OU=Lab/CN=https-server"

# Create extensions file for SAN
cat > server.ext << EOF
authorityKeyIdentifier=keyid,issuer
basicConstraints=CA:FALSE
keyUsage = digitalSignature, nonRepudiation, keyEncipherment, dataEncipherment
subjectAltName = @alt_names

[alt_names]
DNS.1 = https-server
DNS.2 = secure.lab.local
DNS.3 = localhost
IP.1 = 127.0.0.1
EOF

# Sign server certificate with CA
echo "[5/5] Signing server certificate..."
openssl x509 -req -in server.csr \
    -CA ca.crt -CAkey ca.key -CAcreateserial \
    -out server.crt -days 365 -sha256 \
    -extfile server.ext

# Build the chain bundle (leaf + CA) that nginx serves. Without this, the
# server only sends the leaf certificate and B1.3 ("how many certificates
# in the chain?") would only ever show 1.
cat server.crt ca.crt > server-chain.crt

# Clean up
rm -f server.csr server.ext

# Set permissions
chmod 644 *.crt
chmod 600 *.key

echo ""
echo "=== Certificate generation complete ==="
echo ""
echo "Generated files in $CERT_DIR:"
ls -la "$CERT_DIR"
echo ""
echo "CA Certificate (for client trust): ca.crt"
echo "Server Certificate: server.crt"
echo "Server Key: server.key"
echo ""
echo "To inspect the server certificate:"
echo "  openssl x509 -in $CERT_DIR/server.crt -noout -text"
