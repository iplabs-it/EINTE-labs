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
