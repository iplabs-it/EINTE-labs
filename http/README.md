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
│   ├── generate-certs.sh     # TLS certificates
│   ├── student-seed.sh       # Per-student values from the index number
│   └── personalise.sh        # Generates the per-student nginx include and start page
├── certs/                    # Generated certificates
└── docs/                     # Markdown copies of the Word manuals (generated)
    ├── student-guide-part-a.md
    ├── student-guide-part-b.md
    └── student-guide-full.md
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
./bootstrap.sh client   # Connect to client (the session is recorded)
./bootstrap.sh package  # Archive saved files and session recordings for submission
```

## Personalisation and Session Recording

`bootstrap.sh deploy` asks for the student's index number once (kept in
`.student-id`, or taken from `STUDENT_ID` in the environment) and derives a
set of per-student values from it with `scripts/student-seed.sh`:

- the items of the REST API and the id of a created item,
- the `max-age` of `/` and `/private/`,
- the length of a hidden note in the start page (changes its size and compression ratio),
- the validity and an extra SAN of the HTTPS certificate, the HSTS lifetime,
- an `X-Lab-Token` header carried by every response of the lab servers.

`scripts/personalise.sh` writes them to `configs/generated/student.conf`
(nginx `map` variables) and `content/generated/index.html`, both bind-mounted
into the containers. Instructors check a report with the same script:

```bash
scripts/student-seed.sh <index-number>     # prints the values that student must have seen
```

`bootstrap.sh client` records the whole terminal session with `script(1)` to
`content/saved/sessions/` (log + timing file, replayable with `scriptreplay`).
`bootstrap.sh package` archives `content/saved` for submission. Setting
`LAB_LOG_UPLOAD_URL` in the environment (or at the top of `bootstrap.sh`)
additionally uploads each recording as a multipart POST (`student`, `token`,
`log`, `timing`).

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
