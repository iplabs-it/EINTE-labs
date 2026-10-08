# HTTP Protocol Laboratory

**Warsaw University of Technology**  
**Institute of Telecommunications**

A modernized HTTP protocol lab using ContainerLab, designed for hands-on learning of HTTP, caching, and HTTPS/TLS.

## Overview

This lab provides a complete environment for students to learn:

- **HTTP Basics**: Methods, headers, content negotiation
- **Caching Mechanisms**: Cache-Control, ETag, Last-Modified, stale-while-revalidate
- **HTTPS/TLS**: Handshake, certificates, security headers

## Lab Architecture

```
┌─────────────┐     ┌─────────────┐     ┌─────────────┐
│   client    │───▶│ cache-proxy │────▶│  webserver  │
│  (curl,     │     │  (nginx)    │     │  (nginx)    │
│  openssl)   │     └─────────────┘     └─────────────┘
│             │                         
│             │─────────────────────────▶┌─────────────┐
└─────────────┘                          │https-server │
                                         │  (TLS)      │
                                         └─────────────┘
```

## Quick Start

```bash
# 1. Deploy the lab
./bootstrap.sh deploy

# 2. Connect to client container
./bootstrap.sh client

# 3. Start exploring!
curl http://webserver/
curl -I http://cache-proxy/
curl -k https://https-server/
```

## Files Structure

```
http-lab/
├── bootstrap.sh              # Main deployment script
├── http-lab.clab.yml         # ContainerLab topology
├── configs/
│   ├── nginx-webserver.conf  # HTTP server config
│   ├── nginx-cache.conf      # Caching proxy config
│   └── nginx-https.conf      # HTTPS server config
├── content/
│   ├── www/                  # HTTP content
│   └── www-secure/           # HTTPS content
├── scripts/
│   ├── client-init.sh        # Client setup
│   ├── cache-init.sh         # Proxy setup
│   └── generate-certs.sh     # TLS certificates
├── certs/                    # Generated certificates
└── docs/
    ├── student-guide-part-a.md
    ├── student-guide-part-b.md
    └── instructor-key.md
```

## Duration

- **Part A (Basic)**: ~2 hours
- **Part B (Advanced)**: ~2 hours
- **Total**: ~4 hours

## Requirements

- ContainerLab
- Docker
- OpenSSL

## Commands

```bash
./bootstrap.sh deploy   # Start the lab
./bootstrap.sh destroy  # Stop the lab
./bootstrap.sh status   # Check status
./bootstrap.sh client   # Connect to client
```

## Topics Covered

### Part A (Basic)
- HTTP request/response structure
- HTTP methods (GET, POST, PUT, DELETE)
- Content negotiation
- Cache-Control directives
- ETag and conditional requests
- Caching proxy behavior

### Part B (Advanced)
- TLS handshake analysis
- Certificate inspection
- Security headers (HSTS, X-Frame-Options, etc.)
- HTTP vs HTTPS traffic comparison
- Stale-while-revalidate
- Performance analysis

## License

Educational use only - Warsaw University of Technology
