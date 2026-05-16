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

The lab VM image ships with `~/EINTE-labs` already cloned. Pull the
latest revision and merge the HTTP-lab branch:

```bash
cd ~/EINTE-labs
git pull
git merge --no-edit origin/lab3-http
```

> **Fallback — VM without the pre-cloned repo.** If `~/EINTE-labs` is
> empty or `git pull` reports *"not a git repository"*, clone it from
> scratch and bring in the lab branch:
>
> ```bash
> cd ~
> rm -rf EINTE-labs                 # only if a non-git EINTE-labs dir is in the way
> git clone https://github.com/iplabs-it/EINTE-labs.git
> cd EINTE-labs
> git merge --no-edit origin/lab3-http
> ```

This populates `~/EINTE-labs/http/` with the lab files.

### Starting the Lab

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
# PART B: Advanced Topics (Approx. 2 hours)

---

## Exercise B1: HTTPS and TLS

### B1.1: TLS Handshake Observation

Connect to the HTTPS server and observe the TLS handshake:

```bash
# Verbose TLS connection
openssl s_client -connect https-server:443 -state
```

**Tasks:**
1. Identify the TLS version negotiated
2. List the handshake states observed
3. What cipher suite was selected?
4. How many certificates are in the chain?

### B1.2: Certificate Inspection

Examine the server certificate in detail:

```bash
# View certificate details
openssl s_client -connect https-server:443 </dev/null 2>/dev/null | \
  openssl x509 -noout -text
```

**Tasks:**
1. Who is the certificate issuer (CA)?
2. Who is the subject?
3. What are the Subject Alternative Names (SANs)?
4. When does the certificate expire?
5. What signature algorithm is used?

### B1.3: Certificate Chain

```bash
# Show full certificate chain
openssl s_client -connect https-server:443 -showcerts </dev/null
```

**Tasks:**
1. How many certificates are shown?
2. Draw the trust chain (CA → Server)
3. Why is a certificate chain necessary?

### B1.4: Cipher Suite Analysis

```bash
# Check supported ciphers
openssl s_client -connect https-server:443 -cipher 'ALL' </dev/null 2>&1 | grep "Cipher"

# Try specific TLS version
openssl s_client -connect https-server:443 -tls1_2 </dev/null 2>&1 | grep -E "(Protocol|Cipher)"
openssl s_client -connect https-server:443 -tls1_3 </dev/null 2>&1 | grep -E "(Protocol|Cipher)"
```

**Tasks:**
1. What cipher is used with TLS 1.2?
2. What cipher is used with TLS 1.3?
3. Why are different ciphers used for different TLS versions?

---

## Exercise B2: HTTPS vs HTTP in Practice

### B2.1: Traffic Comparison

First, capture some HTTP traffic:

```bash
# In one terminal, start capture
tcpdump -i any -A -s 0 'port 80' -c 20 > /tmp/http-capture.txt &

# Make HTTP request
curl http://webserver/

# Wait for capture to finish, then view
cat /tmp/http-capture.txt
```

Now capture HTTPS traffic:

```bash
# Start capture for HTTPS
tcpdump -i any -s 0 'port 443' -c 20 > /tmp/https-capture.txt &

# Make HTTPS request
curl -k https://https-server/

# View capture
cat /tmp/https-capture.txt
```

**Tasks:**
1. Can you read the HTTP request/response in the first capture?
2. Can you read anything meaningful in the HTTPS capture?
3. What specific information is visible even in encrypted traffic?

### B2.2: Security Headers

```bash
curl -I -k https://https-server/
```

**Tasks:**
1. Find and explain each security header:
   - Strict-Transport-Security (HSTS)
   - X-Content-Type-Options
   - X-Frame-Options
   - X-XSS-Protection
2. What attack does each header help prevent?

### B2.3: HTTP to HTTPS Redirect

```bash
# Try HTTP on HTTPS server (port 80)
curl -I http://https-server/

# Follow redirect
curl -I -L http://https-server/
```

**Tasks:**
1. What status code triggers the redirect?
2. What is the Location header value?
3. Why is automatic HTTP→HTTPS redirect important?

---

## Exercise B3: Advanced Caching Scenarios

### B3.1: Stale-While-Revalidate

The `/news/` path uses stale-while-revalidate. Test it:

```bash
# Initial request
curl -I http://cache-proxy/news/
echo "Age after first request:"
curl -sI http://cache-proxy/news/ | grep -i age

# Wait and check age
sleep 30
echo "Age after 30 seconds:"
curl -sI http://cache-proxy/news/ | grep -i age

sleep 35
echo "Age after 65 seconds (past max-age):"
curl -sI http://cache-proxy/news/ | grep -i age
```

**Tasks:**
1. How does Age header change over time?
2. What happens when Age exceeds max-age?
3. Explain the benefit of stale-while-revalidate for user experience

### B3.2: Cache Invalidation Strategies

In a production environment, you often need to invalidate cached content.

```bash
# Check current cache state
curl -I http://cache-proxy/static/styles.css

# Request cache purge (simulated)
curl http://cache-proxy/purge
```

**Tasks:**
1. Research and describe 3 cache invalidation strategies
2. What is the "cache invalidation" problem in computer science?
3. How do CDNs handle cache invalidation?

### B3.3: Vary Header Impact

```bash
# Request with different Accept-Encoding
curl -I http://webserver/
curl -I -H "Accept-Encoding: gzip" http://webserver/
```

**Tasks:**
1. What is the Vary header set to?
2. How does Vary affect caching behavior?
3. Why might too many Vary values hurt cache efficiency?

---

## Exercise B4: HTTP Performance Analysis

### B4.1: Connection Timing

```bash
# Detailed timing information
curl -w "\nTime breakdown:\n\
  DNS lookup: %{time_namelookup}s\n\
  TCP connect: %{time_connect}s\n\
  TLS handshake: %{time_appconnect}s\n\
  Time to first byte: %{time_starttransfer}s\n\
  Total time: %{time_total}s\n" \
  -o /dev/null -s http://webserver/

curl -w "\nTime breakdown:\n\
  DNS lookup: %{time_namelookup}s\n\
  TCP connect: %{time_connect}s\n\
  TLS handshake: %{time_appconnect}s\n\
  Time to first byte: %{time_starttransfer}s\n\
  Total time: %{time_total}s\n" \
  -o /dev/null -s -k https://https-server/
```

**Tasks:**
1. Compare HTTP vs HTTPS timing
2. What additional overhead does TLS add?
3. Which phase takes the longest?

### B4.2: Keep-Alive Connections

```bash
# Multiple requests, new connection each time
time (for i in 1 2 3 4 5; do curl -s http://webserver/ > /dev/null; done)

# Multiple requests, reusing connection
time curl -s http://webserver/ http://webserver/ http://webserver/ http://webserver/ http://webserver/ > /dev/null
```

**Tasks:**
1. Compare the total time for both approaches
2. Why is connection reuse important?
3. What HTTP header controls keep-alive behavior?

---

## Exercise B5: Practical Scenarios

### B5.1: Building a Simple Website Download

Download all resources for offline viewing:

```bash
cd /home/student/saved

# Download main page
curl http://webserver/ -o index.html

# Download CSS
curl http://webserver/static/styles.css -o styles.css

# Download JavaScript
curl http://webserver/static/tracker.js -o tracker.js

# Download image
curl http://webserver/static/images/network-diagram.svg -o network-diagram.svg
```

**Tasks:**
1. Edit index.html to fix the resource paths for local viewing
2. Verify the page renders correctly
3. What tool automates this process? (hint: wget with options)

### B5.2: API Interaction Script

Create a script that interacts with the REST API:

```bash
#!/bin/sh
# Save as /home/student/api-test.sh

printf '=== Getting all items ===\n'
curl -s http://webserver/api/items | jq .

printf '\n=== Getting item 1 ===\n'
curl -s http://webserver/api/items/1 | jq .

printf '\n=== Creating new item ===\n'
curl -s -X POST http://webserver/api/items | jq .

printf '\n=== Updating item 2 ===\n'
curl -s -X PUT http://webserver/api/items/2 | jq .

printf '\n=== Deleting item 3 ===\n'
curl -s -X DELETE http://webserver/api/items/3 | jq .
```

**Tasks:**
1. Run the script and document the output
2. What would you add for error handling?
3. How would you add authentication to API requests?

---

## Part B Deliverables

Submit a report containing:
1. Answers to all tasks with supporting evidence
2. TLS certificate analysis with chain diagram
3. Performance comparison between HTTP and HTTPS
4. Analysis of at least 3 caching scenarios
5. Working API interaction script

---

## Final Checklist

Before submitting, ensure you have:

- [ ] Documented all HTTP methods tested
- [ ] Created caching strategy comparison table
- [ ] Captured and analyzed ETag/conditional requests
- [ ] Examined TLS handshake and certificates
- [ ] Compared HTTP vs HTTPS traffic visibility
- [ ] Tested stale-while-revalidate behavior
- [ ] Measured HTTP vs HTTPS performance
- [ ] Downloaded and fixed website for offline viewing

---

## Stopping the Lab

When finished:

```bash
# Exit client container
exit

# Stop the lab
./bootstrap.sh destroy
```

---

## References

- RFC 7234 - HTTP Caching
- RFC 7232 - HTTP Conditional Requests  
- RFC 8446 - TLS 1.3
- RFC 6797 - HTTP Strict Transport Security (HSTS)
- MDN Web Docs: HTTP Caching
- curl documentation: https://curl.se/docs/

---

*HTTP Protocol Laboratory - Warsaw University of Technology*
