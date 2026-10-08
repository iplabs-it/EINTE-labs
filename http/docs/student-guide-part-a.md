# HTTP Protocol Laboratory
## Student Exercise Guide

**Institute of Telecommunications**  
**Warsaw University of Technology**  
**2024/2025**

---

## Introduction

This laboratory introduces the HTTP protocol, caching mechanisms, and HTTPS/TLS security. You will use command-line tools (`curl`, `openssl`) to interact with web servers and analyze protocol behavior.

**Duration:** 4 hours total (2h basic + 2h advanced)

**Prerequisites:**
- Basic understanding of TCP/IP networking
- Familiarity with command line interface
- Knowledge of client-server architecture

---

## Lab Environment

The lab consists of four containers:

| Container | Role | Address |
|-----------|------|---------|
| client | Your workstation | - |
| cache-proxy | Caching reverse proxy | cache-proxy:80 |
| webserver | HTTP origin server | webserver:80 |
| https-server | HTTPS/TLS server | https-server:443 |

### Fetching the Lab Files

1. Start the lab VM and **make sure your host PC is online**. Open the terminal application.
2. Download the lab files. The commands depend on whether the `~/EINTE-labs`
   folder already exists on your VM. To check, run:

   ```bash
   ls -d ~/EINTE-labs
   ```

   **Case A** – the command prints `/home/iplabs/EINTE-labs` (the folder exists).
   Update it and merge the lab branch:

   ```bash
   cd ~/EINTE-labs
   git pull
   git merge --no-edit origin/lab3-http
   ```

   **Case B** – the command reports *"No such file or directory"* (the folder is
   missing). Clone the repository and merge the lab branch:

   ```bash
   cd ~
   git clone https://github.com/iplabs-it/EINTE-labs.git
   cd EINTE-labs
   git merge --no-edit origin/lab3-http
   ```

3. Check the result. Both cases place the lab files in the `~/EINTE-labs/http` folder:

   ```bash
   ls ~/EINTE-labs/http
   ```

   The listing should include `bootstrap.sh` and `http-lab.clab.yml`. Running
   the Case A commands again later is safe – git just reports *"Already up to date"*.

> **⚠ Troubleshooting**
>
> - If `git pull` reports *"not a git repository"*, `~/EINTE-labs` is not a
>   valid copy of the repository. Remove it with `rm -rf ~/EINTE-labs` and
>   follow Case B.
> - If `git merge` stops with *"Please tell me who you are"* or *"unable to
>   auto-detect email address"*, set a git identity once, then run the
>   `git merge` command again:
>
>   ```bash
>   git config --global user.name "EINTE Student"
>   git config --global user.email "student@einte.lab"
>   ```

### Starting the Lab

Go to the lab folder, deploy the lab environment and connect to the client container:

```bash
cd ~/EINTE-labs/http

# Deploy the lab
./bootstrap.sh deploy

# Connect to the client container
./bootstrap.sh client
```

### Useful Commands

Once inside the client container, these helper commands are available:

- `webserver /path` - GET from origin server
- `proxy /path` - GET via caching proxy  
- `secure /path` - GET from HTTPS server
- `cache_test /path` - Test caching behavior
- `tls_info` - Show TLS certificate information

---

# PART A: HTTP Basics (Approx. 2 hours)

## Exercise A1: HTTP Request/Response Structure

### A1.1: Your First HTTP Request

Connect to the client and make a simple request:

```bash
curl -v http://webserver/
```

**Tasks:**
1. Identify the HTTP request line (method, path, version)
2. List all request headers sent by curl
3. Identify the HTTP response status line
4. What is the server software (check Server header)?
5. What Content-Type does the server return?

**Report:** Include the full request/response headers in your report.

### A1.2: Understanding Headers

Make a HEAD request to retrieve only headers:

```bash
curl -I http://webserver/
```

**Tasks:**
1. Compare the output with the previous GET request
2. What is the Content-Length?
3. Find the ETag value
4. Explain when HEAD method is useful

### A1.3: HTTP Methods

The server provides a simple REST API. Test different methods – the `-i`
option makes curl print the response status line and headers before the body:

```bash
# GET - retrieve items
curl -i http://webserver/api/items

# GET - single item
curl -i http://webserver/api/items/1

# POST - create item
curl -i -X POST http://webserver/api/items

# PUT - update item
curl -i -X PUT http://webserver/api/items/1

# DELETE - remove item
curl -i -X DELETE http://webserver/api/items/1
```

> **Note:** the API is simulated – it returns realistic responses, but changes
> are not stored (e.g. item 1 is still there after the DELETE).

**Tasks:**
1. What HTTP status code does POST return? Why?
2. What is the difference between PUT and POST semantically?
3. Try an unsupported method (e.g., PATCH) - what happens? Check the `Allow` header in the response.

---

## Exercise A2: Content Negotiation

### A2.1: Accept Headers

The server supports gzip compression. Compare:

```bash
# Without compression
curl -I http://webserver/

# Request compression
curl -I -H "Accept-Encoding: gzip" http://webserver/

# Compare the number of body bytes actually transferred
curl -s http://webserver/ | wc -c
curl -s -H "Accept-Encoding: gzip" http://webserver/ | wc -c
```

**Tasks:**
1. What header indicates the response is compressed?
2. Check the Vary header - what does it tell caches?
3. How many bytes does compression save for this page (absolute and in %)?
4. Compare the `ETag` and `Content-Length` headers of the two responses. Why
   does the ETag of the compressed response start with `W/`, and why is
   `Content-Length` missing?

### A2.2: User-Agent Behavior

Every request carries a `User-Agent` header identifying the client. The
`/api/echo` endpoint shows what the server received:

```bash
# Default curl User-Agent
curl http://webserver/api/echo

# Custom User-Agent
curl -H "User-Agent: Mozilla/5.0 (Educational Bot)" http://webserver/api/echo
```

Some servers behave differently based on User-Agent. The `/ua/` page
classifies the client and adapts its response:

```bash
curl -i http://webserver/ua/
curl -i -H "User-Agent: Mozilla/5.0 (Educational Bot)" http://webserver/ua/
curl -i -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0" http://webserver/ua/
```

**Tasks:**
1. Document the default User-Agent string curl sends
2. How does the server classify each client? Which response header reveals it?
3. The "Educational Bot" string starts with `Mozilla/5.0`, yet it is classified
   as a bot. Why do crawlers and other tools put `Mozilla/5.0` in their User-Agent?
4. The `/ua/` responses carry `Vary: User-Agent`. What does this tell a cache,
   and what would go wrong without it?
5. Why might servers care about User-Agent? Is it a reliable way to identify clients?

---

## Exercise A3: HTTP Caching Fundamentals

### A3.1: Understanding Cache-Control

The server has different caching strategies for different paths. Explore:

```bash
# Check headers for each path
curl -I http://webserver/static/styles.css
curl -I http://webserver/dynamic/
curl -I http://webserver/private/
curl -I http://webserver/validate/
curl -I http://webserver/news/
```

**Tasks:**
1. Create a table showing the Cache-Control value for each path
2. Explain what each Cache-Control directive means:
   - `public` vs `private`
   - `max-age`
   - `no-cache` vs `no-store`
   - `must-revalidate`
   - `immutable`
   - `stale-while-revalidate`

### A3.2: ETag and Conditional Requests

ETags enable cache validation without downloading content again.

```bash
# Step 1: Get the ETag
curl -I http://webserver/validate/ 
# Note the ETag value (e.g., "abc123")

# Step 2: Conditional request
curl -I -H 'If-None-Match: "YOUR-ETAG-HERE"' http://webserver/validate/
```

**Tasks:**
1. What status code do you receive for the conditional request?
2. Is there a response body? Why or why not?
3. Calculate bandwidth saved if the resource was 1MB

### A3.3: Last-Modified and If-Modified-Since

Similar to ETag but time-based. First read the resource's `Last-Modified`,
then issue two conditional requests — one with a date *before* it (the
resource HAS changed since) and one with a date *at or after* it (the
resource has NOT changed since).

```bash
# Step 1: read Last-Modified
curl -I http://webserver/static/styles.css
# Note the Last-Modified value, e.g. "Sat, 16 May 2026 14:17:20 GMT"

# Step 2a: ask "has it changed since some date in the past?" → expect 200
curl -I -H "If-Modified-Since: Wed, 01 Jan 2025 00:00:00 GMT" \
     http://webserver/static/styles.css

# Step 2b: replay the actual Last-Modified value → expect 304 Not Modified
curl -I -H "If-Modified-Since: <PASTE-LAST-MODIFIED-HERE>" \
     http://webserver/static/styles.css
```

**Tasks:**
1. What status code do you get for step 2a vs step 2b? Which response carries a body?
2. When would you use `If-Modified-Since` vs `If-None-Match`?
3. What are the advantages and disadvantages of each? Consider clock skew,
   sub-second changes, and resources that change without their mtime changing.

---

## Exercise A4: Caching Proxy Behavior

### A4.1: Cache HIT vs MISS

Access content through the caching proxy:

```bash
# First request - should be MISS
curl -I http://cache-proxy/static/styles.css

# Second request - should be HIT
curl -I http://cache-proxy/static/styles.css

# Third request
curl -I http://cache-proxy/static/styles.css
```

**Tasks:**
1. Check the `X-Cache-Status` header for each request
2. What values can X-Cache-Status have? (MISS, HIT, BYPASS, etc.)
3. Check the `Age` header - what does it represent?

### A4.2: Cache Bypass

Test paths that bypass the cache:

```bash
# Dynamic content - never cached
curl -I http://cache-proxy/dynamic/

# API - never cached
curl -I http://cache-proxy/api/time
curl -I http://cache-proxy/api/time
```

**Tasks:**
1. Verify these always show MISS or BYPASS
2. Why should API responses typically not be cached?

### A4.3: Private Content

```bash
# Private content through proxy
curl -I http://cache-proxy/private/
curl -I http://cache-proxy/private/
```

**Tasks:**
1. Does the proxy cache private content?
2. Explain why this behavior is important for security

---

## Part A Deliverables

Submit a report containing:
1. Answers to all tasks
2. Screenshots/outputs demonstrating key concepts
3. A summary table of caching strategies observed

---
