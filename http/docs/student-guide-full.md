# HTTP Protocol Laboratory
## Part A — HTTP Basics

*curl · HTTP/1.1 · Caching · Containers*

**Warsaw University of Technology**  
**Institute of Telecommunications**

---

## 1 INTRODUCTION

This laboratory introduces the HTTP protocol, caching mechanisms, and HTTPS/TLS security. You will use command-line tools (`curl`, `openssl`) to interact with web servers and analyze protocol behavior. The lab is split into two parts: this manual covers **Part A — HTTP Basics**. HTTPS/TLS is covered in the Part B manual.

**Prerequisites:**

- Basic understanding of TCP/IP networking
- Familiarity with the command-line interface
- Knowledge of HTTP client–server architecture

>
>
> The practical part of the exercise is carried out using a VirtualBox virtual machine (VM). The lab environment is hosted on this VM and is based on Docker containers (`docker.com`), and ContainerLab (`containerlab.dev`)
>
> The final deliverable of the exercise is a report (**PDF format is mandatory**) that should document the findings from the practical part - this guide includes questions and remarks to direct the mandatory content of the report. The report should be clear, logical, concise, and formatted in a style typical for technical documents.

## 2 LAB ENVIRONMENT

To set up the virtual lab environment, follow these steps:

1. Start the lab VM and **make sure your host PC is online**. Open the terminal application.
2. Download the lab files. The commands depend on whether the `~/EINTE-labs` folder already exists on your VM. To check, run:

   ```bash
   ls -d ~/EINTE-labs/.git
   ```

   **Case A** – the command prints `/home/iplabs/EINTE-labs/.git` (a copy of the repository is already there). Fetch the latest version and merge the lab branch:

   ```bash
   cd ~/EINTE-labs
   git fetch
   git merge --no-edit origin/lab3-http
   ```

   **Case B** – the command reports "No such file or directory" (there is no repository yet). Clone the repository and merge the lab branch:

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

   The listing should include `bootstrap.sh` and `http-lab.clab.yml`. Running the Case A commands again later is safe – if nothing has changed, git merge just reports "Already up to date".

> **⚠** *Troubleshooting*
>
> If `git fetch` reports "not a git repository", `~/EINTE-labs` is not a valid copy of the repository. Remove it with `rm -rf ~/EINTE-labs` and follow Case B.
>
> If `git merge` stops with "Please tell me who you are" or "unable to auto-detect email address", set a git identity once, then run the `git merge` command again:
>
> ```bash
> git config --global user.name "EINTE Student"
> git config --global user.email "student@einte.lab"
> ```

The lab consists of four containers, summarised in Table 1.

| Container | Role | Address |
|---|---|---|
| `client` | Your workstation | — |
| `cache-proxy` | Caching reverse proxy | `cache-proxy:80` |
| `webserver` | HTTP origin server | `webserver:80` |
| `https-server` | HTTPS/TLS server | `https-server:443` |

*Table 1. Lab containers*

### 2.1 Starting the Lab

Go to the lab folder, deploy the lab environment and connect to the `client` container:

```bash
cd ~/EINTE-labs/http
./bootstrap.sh deploy
./bootstrap.sh client
```

### 2.2 Helper Commands

Inside the `client` container, the helper commands shown in Table 2 are available to shorten common requests.

| Command | Description |
|---|---|
| `webserver /path` | GET from the origin server |
| `proxy /path` | GET via the caching proxy |
| `secure /path` | GET from the HTTPS server (Part B) |
| `cache_test /path` | Test caching behaviour |
| `tls_info` | Show TLS certificate information (Part B) |

*Table 2. Client-side helper commands*

## 3 HTTP BASICS — PART A EXERCISES

**Approximate time:** 2 hours. Each exercise builds on the previous one; work through them in order.

### 3.1 Exercise A1 — HTTP Request/Response Structure

#### A1.1 Your First HTTP Request

Connect to the client container and make a simple verbose request:

```bash
curl -v http://webserver/
```

**Tasks:**

1. Identify the HTTP request line (method, path, version).
2. List all request headers sent by `curl`.
3. Identify the HTTP response status line.
4. What is the server software? (check the `Server` header)
5. What `Content-Type` does the server return?

> ***📝 Report:*** *Include the full request/response headers in your report.*

#### A1.2 Understanding Headers

Make a HEAD request to retrieve only the headers:

```bash
curl -I http://webserver/
```

**Tasks:**

1. Compare the output with the previous GET request.
2. What is the `Content-Length`?
3. Find the `ETag` value.
4. Explain when the HEAD method is useful.

#### A1.3 HTTP Methods

The server exposes a simple REST API. Test different methods – the `-i` option makes curl print the response status line and headers before the body:

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

***Note:*** *the API is simulated – it returns realistic responses, but changes are not stored (e.g. item 1 is still there after the DELETE).*

**Tasks:**

1. What HTTP status code does `POST` return? Why?
2. What is the semantic difference between `PUT` and `POST`?
3. Try an unsupported method (e.g., `PATCH`) — what happens? Check the `Allow` header in the response.

### 3.2 Exercise A2 — Content Negotiation

#### A2.1 Accept Headers

The server supports gzip compression. Compare the two responses:

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
2. Check the Vary header — what does it tell caches?
3. How many bytes does compression save for this page (absolute and in %)?
4. Compare the `ETag` and `Content-Length` headers of the two responses. Why does the ETag of the compressed response start with `W/`, and why is `Content-Length` missing?

#### A2.2 User-Agent Behaviour

Every request carries a `User-Agent` header identifying the client. The `/api/echo` endpoint shows what the server received:

```bash
# Default curl User-Agent
curl http://webserver/api/echo

# Custom User-Agent
curl -H "User-Agent: Mozilla/5.0 (Educational Bot)" http://webserver/api/echo
```

Some servers behave differently based on User-Agent. The `/ua/` page classifies the client and adapts its response:

```bash
curl -i http://webserver/ua/
curl -i -H "User-Agent: Mozilla/5.0 (Educational Bot)" http://webserver/ua/
curl -i -H "User-Agent: Mozilla/5.0 (X11; Linux x86_64) Firefox/128.0" http://webserver/ua/
```

**Tasks:**

1. Document the default User-Agent string curl sends.
2. How does the server classify each client? Which response header reveals it?
3. The “Educational Bot” string starts with `Mozilla/5.0`, yet it is classified as a bot. Why do crawlers and other tools put `Mozilla/5.0` in their User-Agent?
4. The `/ua/` responses carry `Vary: User-Agent`. What does this tell a cache, and what would go wrong without it?
5. Why might servers care about User-Agent? Is it a reliable way to identify clients?

### 3.3 Exercise A3 — HTTP Caching Fundamentals

#### A3.1 Understanding Cache-Control

The server applies different caching strategies for different paths. Check the headers for each:

```bash
curl -I http://webserver/static/styles.css
curl -I http://webserver/dynamic/
curl -I http://webserver/private/
curl -I http://webserver/validate/
curl -I http://webserver/news/
```

***Note:*** `X-Cache-Strategy` *is an informal label added by the lab server to help you navigate. It is not a standard header – browsers and caches act only on* `Cache-Control`*.*

**Tasks:**

1. Create a table showing the `Cache-Control` value for each path.
2. Explain what each `Cache-Control` directive means:

   - `public` vs `private`
   - `max-age`
   - `no-cache` vs `no-store`
   - `must-revalidate`
   - `immutable`
   - `stale-while-revalidate`

#### A3.2 ETag and Conditional Requests

ETags enable cache validation without downloading content again. In step 2, the `-w` option makes curl print the status code and the number of body bytes it received (`-o /dev/null` discards the body itself):

```bash
# Step 1: Get the ETag
curl -I http://webserver/validate/
# Note the ETag value, including its double quotes (e.g. "6ac6db0e-668")

# Step 2: Normal GET vs conditional GET
curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" \
     http://webserver/validate/
curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" \
     -H 'If-None-Match: "YOUR-ETAG-HERE"' http://webserver/validate/

# Step 3: Full headers of the conditional response
curl -i -H 'If-None-Match: "YOUR-ETAG-HERE"' http://webserver/validate/
```

Replace only `YOUR-ETAG-HERE`: the header value must contain the ETag inside exactly one pair of double quotes, just as the server sent it. Without the quotes (or with doubled quotes) the ETag does not match and you get `200`.

***Tip:*** *instead of copying the value by hand, you can store it in a shell variable:*

```bash
ETAG=$(curl -sI http://webserver/validate/ | grep -i '^etag' | cut -d' ' -f2 | tr -d '\r')
curl -i -H "If-None-Match: $ETAG" http://webserver/validate/
```

**Tasks:**

1. What status code do you receive for the conditional request?
2. Compare the number of body bytes of the normal and the conditional GET. Why does the conditional response carry no body?
3. Calculate the bandwidth saved if the resource was 1 MB.

#### A3.3 Last-Modified and If-Modified-Since

Similar to ETag but time-based. First read the resource's Last-Modified, then issue two conditional requests — one with a date before it (the resource HAS changed since) and one with a date at or after it (the resource has NOT changed since).

```bash
# Step 1 — read Last-Modified
curl -I http://webserver/static/styles.css
# Note the Last-Modified value, e.g. "Sat, 16 May 2026 14:17:20 GMT"

# Step 2a — IMS in the past (resource has changed since) → expect 200 OK
curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" \
     -H "If-Modified-Since: Wed, 01 Jan 2025 00:00:00 GMT" \
     http://webserver/static/styles.css

# Step 2b — replay the actual Last-Modified value → expect 304 Not Modified
curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" \
     -H "If-Modified-Since: <PASTE-LAST-MODIFIED-HERE>" \
     http://webserver/static/styles.css
```

**Tasks:**

1. What status code do you get for step 2a vs step 2b? Which response carries a body, and how large is it?
2. When would you use `If-Modified-Since` vs `If-None-Match`?
3. What are the advantages and disadvantages of each? Consider clock skew, sub-second changes, and resources whose content changes without their mtime changing.

### 3.4 Exercise A4 — Caching Proxy Behaviour

#### A4.1 Cache HIT vs MISS

Access content through the caching proxy and observe the results of repeated requests:

```bash
# First request - should be MISS
curl -I http://cache-proxy/static/styles.css

# Second request - should be HIT
curl -I http://cache-proxy/static/styles.css

# Third request
curl -I http://cache-proxy/static/styles.css
```

***Tip:*** *the proxy keeps cached content until the lab is redeployed, and* `styles.css` *may be cached for a whole year. If your first request already shows* `HIT`*, the file was cached by an earlier run. The query string is part of the cache key, so adding one gives you a fresh entry:* `curl -I "http://cache-proxy/static/styles.css?run=2"`

**Tasks:**

1. Check the `X-Cache-Status` header for each request.
2. Check the `Age` header — what does it represent? How does it relate to `max-age`?

#### A4.2 Cache Bypass

Test paths that bypass the cache:

```bash
# Dynamic content - never cached
curl -I http://cache-proxy/dynamic/
curl -I http://cache-proxy/dynamic/

# API - never cached
curl -I http://cache-proxy/api/time
curl -I http://cache-proxy/api/time
```

**Tasks:**

1. Verify these always show MISS or BYPASS.
2. `/dynamic/` shows `MISS`, but the API shows `BYPASS-API`. What is the difference? (Hint: compare the `Cache-Control` header of `/dynamic/` with the fact that the proxy is configured to skip its cache for `/api/`.)
3. Why should API responses typically not be cached?

#### A4.3 Private Content

```bash
# Private content through proxy
curl -I http://cache-proxy/private/
curl -I http://cache-proxy/private/
```

A `MISS` on every request means the proxy never stores the response — unlike a single `MISS` followed by `HIT`s.

**Tasks:**

1. Does the proxy cache private content?
2. Explain why this behaviour is important for security.

#### A4.4 Expiry and Revalidation

Cached content does not stay fresh forever. `/news/` is fresh for 60 s (`max-age=60`) and may then be served stale for 30 s more while the proxy refreshes it (`stale-while-revalidate=30`). `/validate/` (`no-cache`) may be stored, but must be revalidated with the origin before every reuse. The `?run=1` query string gives you a fresh cache entry, so the timings below work even if you requested `/news/` before; use another number if you repeat the steps.

```bash
# /news/ - fresh for 60 s, then stale-while-revalidate for 30 s
curl -I "http://cache-proxy/news/?run=1"     # MISS
curl -I "http://cache-proxy/news/?run=1"     # HIT - note the Age
sleep 65
curl -I "http://cache-proxy/news/?run=1"     # STALE - refreshed in the background
curl -I "http://cache-proxy/news/?run=1"     # HIT - note the Age again

# /validate/ - no-cache: stored, but revalidated on every request
curl -I http://cache-proxy/validate/
curl -I http://cache-proxy/validate/
curl -s -o /dev/null -w "%{http_code} %{size_download} bytes\n" \
     -H 'If-None-Match: "YOUR-ETAG-HERE"' http://cache-proxy/validate/
```

Use the same ETag value as in A3.2. The values of `X-Cache-Status` used by the proxy are listed in Table 3.

| Value | Meaning |
|---|---|
| `MISS` | Not in the cache (or not storable) – fetched from the origin |
| `HIT` | Served from the cache while still fresh |
| `EXPIRED` | Cached copy had expired – full response fetched from the origin |
| `STALE` | Expired copy served anyway (allowed by stale-while-revalidate, or because the origin is down) |
| `UPDATING` | Expired copy served while another request is refreshing it |
| `REVALIDATED` | Expired copy confirmed by the origin with 304 Not Modified |
| `BYPASS` | Cache deliberately skipped (this lab labels it BYPASS-API for /api/) |

*Table 3. X-Cache-Status values used by the proxy*

**Tasks:**

1. Record `X-Cache-Status` and `Age` for each `/news/` request. Why is the third response `STALE` rather than `MISS`, and what happens to `Age` afterwards?
2. What would happen if you waited longer than 90 s (max-age + stale-while-revalidate) before the third request? (Optional: try it with `?run=2` and `sleep 95`.)
3. Why does `/validate/` show `REVALIDATED` rather than `HIT`? What does the proxy send to the origin, and what does it get back?
4. Compare the conditional request through the proxy with the one you sent directly to the webserver in A3.2.
5. Which `X-Cache-Status` values did you observe across Exercise A4? Explain each.

## 4 PART A DELIVERABLES

Submit a report containing:

1. Answers to all tasks.
2. Screenshots or terminal outputs demonstrating the key concepts.
3. A summary table of the caching strategies you observed (consolidating Exercises A3 and A4): for each path, its Cache-Control value and the X-Cache-Status values seen through the proxy.

> **⚠** *The clarity and structure of your report will impact your final score. Group related observations together rather than answering question-by-question.*

## 5 STOPPING THE LAB

When you have finished Part A, stop the lab so that it does not keep running (and restart with every VM boot) until Part B:

```bash
# Exit client container
exit

# Stop the lab
./bootstrap.sh destroy
```

Part B starts with *Preparing the Lab*, which updates the files and deploys the lab again.

---

# Part B — Advanced Topics

## 1 INTRODUCTION

This manual is Part B of the HTTP Protocol Laboratory and builds on the foundation laid in Part A. Where Part A focused on the HTTP wire format and caching basics, Part B explores HTTPS/TLS, encrypted traffic analysis, advanced caching scenarios, performance measurement, and practical scripting tasks. The same containerised lab environment is used — section 1.1 explains how to prepare it for this session; see the Part A manual for the helper-command details.

Each exercise builds on the previous one; work through them in order.

### 1.1 Preparing the Lab

Part B is a separate lab session, usually some weeks after Part A, on the same VM. In the meantime the lab files may have been updated, and the Part A lab may still be running: after a VM reboot its containers restart automatically, but with the **old** configuration. Prepare the lab as follows:

1. Start the lab VM and **make sure your host PC is online**. Open the terminal application.
2. Fetch the latest lab files and merge the latest version of the HTTP-lab branch:

   ```bash
   cd ~/EINTE-labs
   git fetch
   git merge --no-edit origin/lab3-http
   ```

   - If git reports *"Your local changes to the following files would be overwritten by merge"*, you edited lab files during Part A. Discard those edits with `git restore .` and run the `git merge` command again. (Your files in `content/saved/` are not affected.)
   - If `~/EINTE-labs` does not exist, follow *Fetching the Lab Files* in the Part A manual (Case B).
3. **Always redeploy the lab**, even if it seems to be running – this replaces any old containers with fresh ones that use the updated files:

   ```bash
   cd ~/EINTE-labs/http
   ./bootstrap.sh deploy
   ./bootstrap.sh client
   ```

The cache of the proxy starts empty after a redeploy; this is expected. Files you saved in `/home/student/saved` during Part A are kept.

The helper commands from Part A (`webserver`, `proxy`, `secure`, `cache_test`, `tls_info`, `tls_handshake`) are available in the client again.

## 2 ADVANCED TOPICS — PART B EXERCISES

### 2.1 Exercise B1 — HTTPS and TLS

#### B1.1 TLS Handshake Observation

Connect to the HTTPS server and observe the TLS handshake:

```bash
# Verbose TLS connection
openssl s_client -connect https-server:443 -state </dev/null
```

`</dev/null` closes the connection right after the handshake. Without it, `s_client` stays connected and waits for you to type an HTTP request – press `Ctrl+C` to leave.

**Tasks:**

1. Identify the TLS version negotiated
2. List the handshake states observed
3. What cipher suite was selected?
4. How many certificates are in the chain?

#### B1.2 Certificate Inspection

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
5. What signature algorithm and public key type are used?

#### B1.3 Certificate Chain

```bash
# Show full certificate chain
openssl s_client -connect https-server:443 -showcerts </dev/null
```

**Tasks:**

1. How many certificates are shown?
2. Draw the trust chain (CA → Server)
3. Why is a certificate chain necessary?
4. This lab server also sends the root CA certificate. Real servers usually send only their own certificate and the intermediate CA(s). Why is sending the root unnecessary?

#### B1.4 Cipher Suite Analysis

```bash
# Which TLS 1.2 ciphers does the server accept? (tests each cipher in turn)
for c in $(openssl ciphers 'ALL:!aNULL:!eNULL' | tr ':' ' '); do
  openssl s_client -connect https-server:443 -tls1_2 -cipher "$c" \
    </dev/null >/dev/null 2>&1 && echo "accepted: $c"
done

# Which TLS 1.3 cipher suites does the server accept?
for c in TLS_AES_128_GCM_SHA256 TLS_AES_256_GCM_SHA384 TLS_CHACHA20_POLY1305_SHA256; do
  openssl s_client -connect https-server:443 -tls1_3 -ciphersuites "$c" \
    </dev/null >/dev/null 2>&1 && echo "accepted: $c"
done

# Which cipher is negotiated for each TLS version?
openssl s_client -connect https-server:443 -tls1_2 </dev/null 2>&1 | \
  grep -E "(Protocol|Cipher)"
openssl s_client -connect https-server:443 -tls1_3 </dev/null 2>&1 | \
  grep -E "(Protocol|Cipher)"
```

**Tasks:**

1. What cipher is used with TLS 1.2? What cipher is used with TLS 1.3?
2. The server is configured with four TLS 1.2 ciphers – two `ECDHE-ECDSA-…` and two `ECDHE-RSA-…`. Which ones are accepted, and why? (Hint: the public key type you found in B1.2.)
3. Why are different ciphers used for different TLS versions?

### 2.2 Exercise B2 — HTTPS vs HTTP in Practice

#### B2.1 Traffic Comparison

Capture the traffic of one HTTP request. `timeout 5` stops the capture after 5 seconds, and `wait` waits until it has finished. `-n` keeps tcpdump from replacing addresses with host names, so a server name can only appear inside the packets themselves:

```bash
# Capture HTTP traffic in the background
timeout 5 tcpdump -n -i any -A -s 0 'port 80' > /tmp/http-capture.txt &
sleep 1

# Make an HTTP request
curl -s http://webserver/ > /dev/null

# Wait for the capture to finish, then view it
wait
cat /tmp/http-capture.txt
```

Now capture HTTPS traffic the same way:

```bash
timeout 5 tcpdump -n -i any -A -s 0 'port 443' > /tmp/https-capture.txt &
sleep 1
curl -s https://https-server/ > /dev/null
wait
cat /tmp/https-capture.txt
```

**Tasks:**

1. Can you read the HTTP request/response in the first capture?
2. Can you read anything meaningful in the HTTPS capture?
3. What specific information is visible even in encrypted traffic? (Hint: search the HTTPS capture for the server's name – where in the TLS handshake does it come from?)

#### B2.2 Security Headers

```bash
curl -I https://https-server/
```

The lab's CA certificate is installed in the client's trust store, so curl can verify the server certificate. On servers with self-signed certificates you will often see `curl -k` instead.

**Tasks:**

1. Find and explain each security header:

   - Strict-Transport-Security (HSTS)
   - X-Content-Type-Options
   - X-Frame-Options
   - X-XSS-Protection
   - Content-Security-Policy
   - Referrer-Policy
2. What attack does each header help prevent?
3. `X-XSS-Protection` is deprecated and ignored by modern browsers. What replaces it?
4. What does curl's `-k` option do, and why is it not needed here?

#### B2.3 HTTP to HTTPS Redirect

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

### 2.3 Exercise B3 — Advanced Caching Scenarios

#### B3.1 Stale-While-Revalidate – Inside and Outside the Window

In A4.4 you saw a stale copy being served shortly after `max-age` expired. Here you compare two cached copies of `/news/` (`max-age=60`, `stale-while-revalidate=30`): copy **a** is requested again *inside* the stale window, copy **b** only *after* it. The query string makes them two separate cache entries. The whole sequence takes about 95 s:

```bash
curl -sI "http://cache-proxy/news/?copy=a" | grep -iE '^age|x-cache-status'
curl -sI "http://cache-proxy/news/?copy=b" | grep -iE '^age|x-cache-status'
sleep 65
echo "--- copy a after 65 s:"
curl -sI "http://cache-proxy/news/?copy=a" | grep -iE '^age|x-cache-status'
sleep 30
echo "--- copy b after 95 s:"
curl -sI "http://cache-proxy/news/?copy=b" | grep -iE '^age|x-cache-status'
echo "--- copy a again:"
curl -sI "http://cache-proxy/news/?copy=a" | grep -iE '^age|x-cache-status'
```

If you repeat the steps, use new names (e.g. `?copy=c`, `?copy=d`).

**Tasks:**

1. Record `X-Cache-Status` and `Age` for each request.
2. Why is copy **a** served `STALE` after 65 s, but copy **b** `REVALIDATED` after 95 s?
3. For which of the two requests did the client have to wait for the origin server? Explain the benefit of stale-while-revalidate for user experience.
4. At the end, copy **a** is a `HIT` with `Age` ≈ 30, although it was first fetched 95 s earlier. Why?

#### B3.2 Vary Header Impact

Request the same resource through the proxy with and without compression:

```bash
curl -sI http://cache-proxy/static/styles.css | grep -iE '^vary|content-encoding|x-cache-status'
curl -sI -H "Accept-Encoding: gzip" http://cache-proxy/static/styles.css | grep -iE '^vary|content-encoding|x-cache-status'
curl -sI http://cache-proxy/static/styles.css | grep -iE 'x-cache-status'
curl -sI -H "Accept-Encoding: gzip" http://cache-proxy/static/styles.css | grep -iE 'x-cache-status'
```

**Tasks:**

1. What is the Vary header set to?
2. Why is the first gzip request a `MISS`, even though the plain copy is already cached? How many copies of `styles.css` does the proxy now hold?
3. How does Vary affect caching behavior?
4. Why might too many Vary values hurt cache efficiency? (Think of `Vary: User-Agent` on the `/ua/` page from A2.2.)

#### B3.3 Cache Invalidation Strategies

In a production environment, you often need to invalidate cached content before it expires. The lab proxy supports **purging**: a `PURGE` request removes a URL from the cache.

```bash
# Check current cache state (should be HIT after B3.2)
curl -sI http://cache-proxy/static/styles.css | grep -iE 'x-cache-status|^age'

# Purge the cached copies of styles.css
curl -X PURGE http://cache-proxy/static/styles.css

# The next request has to go to the origin again
curl -sI http://cache-proxy/static/styles.css | grep -iE 'x-cache-status|^age'

# Alternative strategy: a versioned URL is a new cache key
curl -sI "http://cache-proxy/static/styles.css?v=2" | grep -iE 'x-cache-status'
```

**Tasks:**

1. What does the proxy report after the purge, and how many files were removed? Relate the number to B3.2.
2. Compare three invalidation strategies you have now seen in the lab: expiry (`max-age`, A4.4), purging, and versioned URLs (`?v=2`). What are the advantages and disadvantages of each? Why are versioned URLs a natural fit for resources sent with `immutable`?
3. What is the "cache invalidation" problem in computer science?
4. How do CDNs handle cache invalidation?

### 2.4 Exercise B4 — HTTP Performance Analysis

#### B4.1 Connection Timing

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
  -o /dev/null -s https://https-server/
```

The values are cumulative: each one is measured from the start of the request. Run each command a few times – single measurements vary.

***Note:*** *if all phases show exactly the same value (e.g.* `0.024000s` *everywhere), the VM's clock is too coarse for this measurement – ask your instructor.*

**Tasks:**

1. Compare HTTP vs HTTPS timing
2. What additional overhead does TLS add?
3. Which phase takes the longest?

#### B4.2 Keep-Alive Connections

```bash
# Multiple requests, new connection each time
time (for i in 1 2 3 4 5; do curl -s http://webserver/ > /dev/null; done)

# Multiple requests, reusing connection
time curl -s http://webserver/ http://webserver/ http://webserver/ \
          http://webserver/ http://webserver/ > /dev/null

# Show that curl reuses the connection
curl -sv http://webserver/ http://webserver/ -o /dev/null -o /dev/null 2>&1 | \
  grep -iE "connected to|re-using"
```

**Tasks:**

1. Compare the total time for both approaches
2. Why is connection reuse important?
3. What HTTP header controls keep-alive behavior?

### 2.5 Exercise B5 — Practical Scenarios

#### B5.1 Building a Simple Website Download

Download all resources for offline viewing. The client's `/home/student/saved` folder is shared with the VM: on the VM it is `~/EINTE-labs/http/content/saved`.

```bash
cd /home/student/saved

# Download main page
curl http://webserver/ -o index.html

# Download CSS
curl http://webserver/static/styles.css -o styles.css

# Download JavaScript
curl http://webserver/static/tracker.js -o tracker.js

# Download image
curl http://webserver/static/images/network-diagram.svg \
  -o network-diagram.svg
```

To view the page, open `file:///home/iplabs/EINTE-labs/http/content/saved/index.html` in the VM's web browser. You can edit `index.html` inside the client with `vi`, or on the VM after you leave the client shell with `exit` – `./bootstrap.sh client` then hands the saved files over to your VM user.

**Tasks:**

1. Edit index.html to fix the resource paths for local viewing
2. Verify the page renders correctly
3. What tool automates this process? (hint: wget with options)

#### B5.2 API Interaction Script

Create a script that interacts with the REST API. Save it as `/home/student/saved/api-test.sh`, so that it is kept on the VM (`~/EINTE-labs/http/content/saved/api-test.sh`) after the lab is stopped:

```bash
#!/bin/sh

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

Run it with `sh /home/student/saved/api-test.sh`.

**Tasks:**

1. Run the script and document the output
2. What would you add for error handling?
3. How would you add authentication to API requests?

## 3 PART B DELIVERABLES

Submit a report containing:

1. Answers to all tasks with supporting evidence.
2. TLS certificate analysis with a chain diagram.
3. Performance comparison between HTTP and HTTPS.
4. Analysis of at least three caching scenarios.
5. Working API interaction script.

## 4 FINAL CHECKLIST

Before submitting your *combined* Part A + Part B report, verify you have completed everything below. The list spans both manuals.

- [ ] Documented all HTTP methods tested
- [ ] Created a caching strategy comparison table
- [ ] Captured and analysed ETag / conditional requests
- [ ] Examined the TLS handshake and certificates
- [ ] Compared HTTP vs HTTPS traffic visibility
- [ ] Tested `stale-while-revalidate` behaviour
- [ ] Purged a cached resource and compared invalidation strategies
- [ ] Measured HTTP vs HTTPS performance
- [ ] Downloaded and fixed a website for offline viewing

## 5 STOPPING THE LAB

When you are finished with the lab, clean up:

```bash
# Exit client container
exit

# Stop the lab
./bootstrap.sh destroy
```

Files in `~/EINTE-labs/http/content/saved` (your downloaded website and `api-test.sh`) stay on the VM after the lab is stopped.

## 6 REFERENCES

- RFC 7234 — HTTP Caching
- RFC 7232 — HTTP Conditional Requests
- RFC 8446 — TLS 1.3
- RFC 6797 — HTTP Strict Transport Security (HSTS)
- MDN Web Docs: HTTP Caching
- curl documentation: https://curl.se/docs/
