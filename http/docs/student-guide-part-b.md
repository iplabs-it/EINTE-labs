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
