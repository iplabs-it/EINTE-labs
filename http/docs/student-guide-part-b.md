# PART B: Advanced Topics (Approx. 2 hours)

---

## Preparing the Lab

Part B is a separate lab session, usually some weeks after Part A, on the
same VM. In the meantime the lab files may have been updated, and the Part A
lab may still be running: after a VM reboot its containers restart
automatically, but with the **old** configuration. Prepare the lab as follows:

1. Start the lab VM and **make sure your host PC is online**. Open the terminal application.
2. Update the lab files and merge the latest version of the HTTP-lab branch:

   ```bash
   cd ~/EINTE-labs
   git pull
   git merge --no-edit origin/lab3-http
   ```

   - If git reports *"Your local changes to the following files would be
     overwritten by merge"*, you edited lab files during Part A. Discard those
     edits with `git restore .` and run the `git merge` command again. (Your
     files in `content/saved/` are not affected.)
   - If `~/EINTE-labs` does not exist, follow *Fetching the Lab Files* in the
     Part A manual (Case B).

3. **Always redeploy the lab**, even if it seems to be running – this replaces
   any old containers with fresh ones that use the updated files:

   ```bash
   cd ~/EINTE-labs/http
   ./bootstrap.sh deploy
   ./bootstrap.sh client
   ```

   The cache of the proxy starts empty after a redeploy; this is expected.
   Files you saved in `/home/student/saved` during Part A are kept.

The helper commands from Part A (`webserver`, `proxy`, `secure`, `cache_test`,
`tls_info`, `tls_handshake`) are available in the client again.

---

## Exercise B1: HTTPS and TLS

### B1.1: TLS Handshake Observation

Connect to the HTTPS server and observe the TLS handshake:

```bash
# Verbose TLS connection
openssl s_client -connect https-server:443 -state </dev/null
```

`</dev/null` closes the connection right after the handshake. Without it,
`s_client` stays connected and waits for you to type an HTTP request – press
`Ctrl+C` to leave.

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
5. What signature algorithm and public key type are used?

### B1.3: Certificate Chain

```bash
# Show full certificate chain
openssl s_client -connect https-server:443 -showcerts </dev/null
```

**Tasks:**
1. How many certificates are shown?
2. Draw the trust chain (CA → Server)
3. Why is a certificate chain necessary?
4. This lab server also sends the root CA certificate. Real servers usually
   send only their own certificate and the intermediate CA(s). Why is sending
   the root unnecessary?

### B1.4: Cipher Suite Analysis

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
2. The server is configured with four TLS 1.2 ciphers – two `ECDHE-ECDSA-…`
   and two `ECDHE-RSA-…`. Which ones are accepted, and why? (Hint: the public
   key type you found in B1.2.)
3. Why are different ciphers used for different TLS versions?

---

## Exercise B2: HTTPS vs HTTP in Practice

### B2.1: Traffic Comparison

Capture the traffic of one HTTP request. `timeout 5` stops the capture after
5 seconds, and `wait` waits until it has finished:

```bash
# Capture HTTP traffic in the background
timeout 5 tcpdump -i any -A -s 0 'port 80' > /tmp/http-capture.txt &
sleep 1

# Make an HTTP request
curl -s http://webserver/ > /dev/null

# Wait for the capture to finish, then view it
wait
cat /tmp/http-capture.txt
```

Now capture HTTPS traffic the same way:

```bash
timeout 5 tcpdump -i any -A -s 0 'port 443' > /tmp/https-capture.txt &
sleep 1
curl -s https://https-server/ > /dev/null
wait
cat /tmp/https-capture.txt
```

**Tasks:**
1. Can you read the HTTP request/response in the first capture?
2. Can you read anything meaningful in the HTTPS capture?
3. What specific information is visible even in encrypted traffic? (Hint:
   search the HTTPS capture for the server's name – where in the TLS
   handshake does it come from?)

### B2.2: Security Headers

```bash
curl -I https://https-server/
```

The lab's CA certificate is installed in the client's trust store, so curl can
verify the server certificate. On servers with self-signed certificates you
will often see `curl -k` instead.

**Tasks:**
1. Find and explain each security header:
   - Strict-Transport-Security (HSTS)
   - X-Content-Type-Options
   - X-Frame-Options
   - X-XSS-Protection
   - Content-Security-Policy
   - Referrer-Policy
2. What attack does each header help prevent?
3. `X-XSS-Protection` is deprecated and ignored by modern browsers. What
   replaces it?
4. What does curl's `-k` option do, and why is it not needed here?

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

### B3.1: Stale-While-Revalidate – Inside and Outside the Window

In A4.4 you saw a stale copy being served shortly after `max-age` expired.
Here you compare two cached copies of `/news/` (`max-age=60`,
`stale-while-revalidate=30`): copy **a** is requested again *inside* the
stale window, copy **b** only *after* it. The query string makes them two
separate cache entries. The whole sequence takes about 95 s:

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
3. For which of the two requests did the client have to wait for the origin
   server? Explain the benefit of stale-while-revalidate for user experience.
4. At the end, copy **a** is a `HIT` with `Age` ≈ 30, although it was first
   fetched 95 s earlier. Why?

### B3.2: Vary Header Impact

Request the same resource through the proxy with and without compression:

```bash
curl -sI http://cache-proxy/static/styles.css | grep -iE '^vary|content-encoding|x-cache-status'
curl -sI -H "Accept-Encoding: gzip" http://cache-proxy/static/styles.css | grep -iE '^vary|content-encoding|x-cache-status'
curl -sI http://cache-proxy/static/styles.css | grep -iE 'x-cache-status'
curl -sI -H "Accept-Encoding: gzip" http://cache-proxy/static/styles.css | grep -iE 'x-cache-status'
```

**Tasks:**
1. What is the Vary header set to?
2. Why is the first gzip request a `MISS`, even though the plain copy is
   already cached? How many copies of `styles.css` does the proxy now hold?
3. How does Vary affect caching behavior?
4. Why might too many Vary values hurt cache efficiency? (Think of
   `Vary: User-Agent` on the `/ua/` page from A2.2.)

### B3.3: Cache Invalidation Strategies

In a production environment, you often need to invalidate cached content
before it expires. The lab proxy supports **purging**: a `PURGE` request
removes a URL from the cache.

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
1. What does the proxy report after the purge, and how many files were
   removed? Relate the number to B3.2.
2. Compare three invalidation strategies you have now seen in the lab:
   expiry (`max-age`, A4.4), purging, and versioned URLs (`?v=2`). What are
   the advantages and disadvantages of each? Why are versioned URLs a natural
   fit for resources sent with `immutable`?
3. What is the "cache invalidation" problem in computer science?
4. How do CDNs handle cache invalidation?

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
  -o /dev/null -s https://https-server/
```

The values are cumulative: each one is measured from the start of the request.
Run each command a few times – single measurements vary.

> **Note:** if all phases show exactly the same value (e.g. `0.024000s`
> everywhere), the VM's clock is too coarse for this measurement – ask your
> instructor.

**Tasks:**
1. Compare HTTP vs HTTPS timing
2. What additional overhead does TLS add?
3. Which phase takes the longest?

### B4.2: Keep-Alive Connections

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

---

## Exercise B5: Practical Scenarios

### B5.1: Building a Simple Website Download

Download all resources for offline viewing. The client's `/home/student/saved`
folder is shared with the VM: on the VM it is
`~/EINTE-labs/http/content/saved`.

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

To view the page, open
`file:///home/iplabs/EINTE-labs/http/content/saved/index.html` in the VM's web
browser. You can edit `index.html` inside the client with `vi`, or on the VM
after you leave the client shell with `exit` – `./bootstrap.sh client` then
hands the saved files over to your VM user.

**Tasks:**
1. Edit index.html to fix the resource paths for local viewing
2. Verify the page renders correctly
3. What tool automates this process? (hint: wget with options)

### B5.2: API Interaction Script

Create a script that interacts with the REST API. Save it as
`/home/student/saved/api-test.sh`, so that it is kept on the VM
(`~/EINTE-labs/http/content/saved/api-test.sh`) after the lab is stopped:

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
- [ ] Purged a cached resource and compared invalidation strategies
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

Files in `~/EINTE-labs/http/content/saved` (your downloaded website and
`api-test.sh`) stay on the VM after the lab is stopped.

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
