#!/bin/sh
# Cache proxy initialization script

echo "=== Initializing Cache Proxy ==="

# Create cache directory
mkdir -p /var/cache/nginx
chown nginx:nginx /var/cache/nginx

echo "=== Cache proxy initialization complete ==="
