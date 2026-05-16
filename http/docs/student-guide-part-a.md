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

### Starting the Lab

```bash
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

The server provides a simple REST API. Test different methods:

```bash
# GET - retrieve items
curl http://webserver/api/items

# GET - single item
curl http://webserver/api/items/1

# POST - create item
curl -X POST http://webserver/api/items

# PUT - update item
curl -X PUT http://webserver/api/items/1

# DELETE - remove item
curl -X DELETE http://webserver/api/items/1
```

**Tasks:**
1. What HTTP status code does POST return? Why?
2. What is the difference between PUT and POST semantically?
3. Try an unsupported method (e.g., PATCH) - what happens?

---

## Exercise A2: Content Negotiation

### A2.1: Accept Headers

The server supports gzip compression. Compare:

```bash
# Without compression
curl -I http://webserver/

# Request compression
curl -I -H "Accept-Encoding: gzip" http://webserver/
```

**Tasks:**
1. What header indicates the response is compressed?
2. Check the Vary header - what does it tell caches?

### A2.2: User-Agent Behavior

Some servers behave differently based on User-Agent:

```bash
# Default curl User-Agent
curl -I http://webserver/

# Custom User-Agent
curl -I -H "User-Agent: Mozilla/5.0 (Educational Bot)" http://webserver/
```

**Tasks:**
1. Document the default User-Agent string curl sends
2. Why might servers care about User-Agent?

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

Similar to ETag but time-based:

```bash
# Get Last-Modified
curl -I http://webserver/static/styles.css

# Conditional request with time
curl -I -H "If-Modified-Since: Wed, 01 Jan 2025 00:00:00 GMT" http://webserver/static/styles.css
```

**Tasks:**
1. When would you use If-Modified-Since vs If-None-Match?
2. What are the advantages/disadvantages of each?

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
