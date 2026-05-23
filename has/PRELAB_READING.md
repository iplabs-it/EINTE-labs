# Pre-Lab Reading: HTTP Adaptive Streaming Fundamentals

**Read this document before attending the lab session.**  
**Estimated reading time: 20-25 minutes**

---

## 1. Introduction: The Video Streaming Challenge

When you watch a video on Netflix, YouTube, or any modern streaming platform, you're experiencing a remarkably complex system that solves several hard problems simultaneously:

- **Variable network conditions** — Your bandwidth fluctuates as you move, as other users join your network, or as congestion occurs
- **Diverse devices** — The same content must work on a 4K TV and a smartphone on cellular
- **User expectations** — People expect instant start, no buffering, and the best possible quality

Traditional video delivery (progressive download) fails here: if you download a 1080p file but your bandwidth drops, playback stalls. HTTP Adaptive Streaming (HAS) solves this elegantly.

---

## 2. The Core Idea: Multiple Qualities, Client Choice

HAS works on a simple but powerful principle:

> **Encode the same video at multiple quality levels, chop each into small segments, and let the client choose which quality to download segment-by-segment.**

```
Original Video
     │
     ▼
┌─────────────────────────────────────────────────┐
│              Encoder (e.g., ffmpeg)             │
└─────────────────────────────────────────────────┘
     │
     ├──► 1080p @ 5 Mbps  ──► [seg1][seg2][seg3][seg4]...
     ├──► 720p  @ 2 Mbps  ──► [seg1][seg2][seg3][seg4]...
     ├──► 480p  @ 1 Mbps  ──► [seg1][seg2][seg3][seg4]...
     └──► 360p  @ 0.5Mbps ──► [seg1][seg2][seg3][seg4]...
```

Each segment is typically 2-10 seconds of video. The client can switch quality at any segment boundary.

---

## 3. The Two Major Standards: DASH and HLS

### 3.1 DASH (Dynamic Adaptive Streaming over HTTP)

- **Developed by:** MPEG (ISO standard)
- **Manifest format:** MPD (Media Presentation Description) — XML file
- **Segment format:** Typically fragmented MP4 (.m4s) or WebM
- **Used by:** YouTube, Netflix, Amazon Prime, most Android apps

### 3.2 HLS (HTTP Live Streaming)

- **Developed by:** Apple
- **Manifest format:** M3U8 playlist (text-based)
- **Segment format:** MPEG-TS (.ts) or fragmented MP4 (.m4s)
- **Used by:** Apple devices, Twitch, many live streams

Both achieve the same goal with different manifest formats. This lab uses DASH, but the concepts apply equally to HLS.

---

## 4. Anatomy of a DASH Stream

### 4.1 The MPD Manifest

The MPD (Media Presentation Description) is an XML file that tells the client everything it needs to know:

```xml
<?xml version="1.0" encoding="utf-8"?>
<MPD xmlns="urn:mpeg:dash:schema:mpd:2011"
     type="static"
     mediaPresentationDuration="PT60S">
  
  <Period id="0" start="PT0S">
    <AdaptationSet contentType="video" segmentAlignment="true">
      
      <!-- Quality Level 1: Low -->
      <Representation id="0" bandwidth="400000" width="640" height="360">
        <SegmentTemplate 
          initialization="init-$RepresentationID$.m4s"
          media="$RepresentationID$-$Number%05d$.m4s"
          duration="2000000" 
          timescale="1000000"/>
      </Representation>
      
      <!-- Quality Level 2: Medium -->
      <Representation id="1" bandwidth="800000" width="854" height="480">
        <SegmentTemplate ... />
      </Representation>
      
      <!-- Quality Level 3: High -->
      <Representation id="2" bandwidth="2500000" width="1920" height="1080">
        <SegmentTemplate ... />
      </Representation>
      
    </AdaptationSet>
  </Period>
</MPD>
```

**Key elements:**

| Element | Purpose |
|---------|---------|
| `mediaPresentationDuration` | Total video length |
| `AdaptationSet` | Groups related streams (all video, or all audio) |
| `Representation` | One quality variant |
| `bandwidth` | Required bitrate in bits/second |
| `SegmentTemplate` | Pattern for constructing segment URLs |
| `timescale` / `duration` | Segment duration (duration/timescale = seconds) |

### 4.2 Segment Files

For a 60-second video with 2-second segments and 3 quality levels:

```
init-0.m4s          ← Initialization (codec info) for 360p
init-1.m4s          ← Initialization for 480p  
init-2.m4s          ← Initialization for 1080p
0-00001.m4s         ← Segment 1, 360p quality
0-00002.m4s         ← Segment 2, 360p quality
...
1-00001.m4s         ← Segment 1, 480p quality
1-00002.m4s         ← Segment 2, 480p quality
...
2-00001.m4s         ← Segment 1, 1080p quality
...
```

The client first downloads the MPD, then the appropriate `init-*.m4s`, then segments sequentially.

---

## 5. Adaptive Bitrate (ABR) Algorithms

The "adaptive" part of adaptive streaming happens client-side. The ABR algorithm decides which quality to request for each segment.

### 5.1 The ABR Decision Problem

Before downloading segment N, the client must choose a quality level. It has:

- **Historical throughput measurements** from previous downloads
- **Current buffer level** (seconds of video ready to play)
- **Available representations** from the MPD

It wants to:
- **Maximize quality** (user experience)
- **Avoid rebuffering** (playback stalls are very annoying)
- **Minimize switches** (quality oscillation is distracting)

These goals conflict! High quality risks rebuffering; being too conservative wastes bandwidth.

### 5.2 Throughput-Based ABR

The simplest approach: estimate available bandwidth, select the highest bitrate that fits.

```
estimated_bandwidth = measure_recent_throughput()
safe_bandwidth = estimated_bandwidth × safety_factor  # e.g., 0.7

for each representation (highest to lowest):
    if representation.bitrate <= safe_bandwidth:
        return representation
```

**Pros:** Simple, reactive  
**Cons:** Oscillates when bandwidth fluctuates, doesn't consider buffer

### 5.3 Buffer-Based ABR (BBA/BOLA)

More sophisticated: use buffer level to make decisions.

```
if buffer_level < LOW_THRESHOLD:
    return lowest_quality        # Emergency: avoid rebuffer
elif buffer_level > HIGH_THRESHOLD:
    return highest_quality       # Comfortable: maximize quality
else:
    return interpolate(buffer_level)  # Proportional selection
```

**Pros:** More stable, avoids rebuffering  
**Cons:** Slower to react to bandwidth changes

### 5.4 Hybrid Approaches

Real players (Netflix, YouTube) combine both:
- Use throughput estimation for upper bound
- Use buffer level for stability
- Add rules for startup, seeking, and recovery

---

## 6. Quality of Experience (QoE) Metrics

How do we measure if streaming is "good"? Key metrics:

| Metric | Definition | User Impact |
|--------|------------|-------------|
| **Average bitrate** | Mean quality level played | Higher = sharper video |
| **Rebuffering ratio** | Time spent stalled / total time | >1% is noticeable |
| **Startup delay** | Time from click to first frame | <2s expected |
| **Quality switches** | Number of resolution changes | Fewer = smoother experience |
| **Switch magnitude** | How big each quality jump is | Smaller jumps less noticeable |

Research shows rebuffering is the #1 predictor of user abandonment — people will accept lower quality to avoid stalls.

---

## 7. Network Considerations

### 7.1 Why HTTP?

HAS uses plain HTTP (typically over TCP) rather than specialized protocols like RTP/RTSP:

- **Works everywhere** — passes through firewalls, proxies, NATs
- **Leverages CDN infrastructure** — cacheable, scalable
- **Simple server** — just a web server, no special software
- **Reliable delivery** — TCP handles packet loss

### 7.2 TCP Behavior Matters

Since HAS uses TCP, understanding TCP throughput is important:

- **Slow start** — new connections ramp up gradually
- **Congestion control** — throughput drops when loss detected
- **RTT sensitivity** — high latency = lower throughput
- **Bandwidth-delay product** — buffers must be sized correctly

This is why ABR algorithms use safety factors — TCP throughput varies!

### 7.3 Segment Size Trade-offs

| Segment Duration | Pros | Cons |
|------------------|------|------|
| Short (2s) | Fast adaptation, low latency | More requests, less compression efficiency |
| Long (10s) | Better compression, fewer requests | Slow adaptation, higher latency |

Most services use 2-6 second segments as a compromise.

---

## 8. Traffic Shaping for Testing

In this lab, you'll use Linux `tc` (traffic control) to simulate network conditions:

### 8.1 HTB (Hierarchical Token Bucket)

Rate limiting — controls maximum bandwidth:

```bash
tc qdisc add dev eth0 root handle 1: htb default 10
tc class add dev eth0 parent 1: classid 1:10 htb rate 5mbit
```

This limits outbound traffic to 5 Mbps.

### 8.2 netem (Network Emulator)

Adds delay, loss, jitter:

```bash
tc qdisc add dev eth0 parent 1:10 handle 10: netem delay 50ms loss 1%
```

This adds 50ms latency and 1% packet loss.

### 8.3 Combining Both

Real networks have both bandwidth limits AND latency:

```bash
# 3 Mbps with 100ms delay and 0.5% loss (typical mobile network)
tc qdisc add dev eth0 root handle 1: htb default 10
tc class add dev eth0 parent 1: classid 1:10 htb rate 3mbit
tc qdisc add dev eth0 parent 1:10 netem delay 100ms loss 0.5%
```

---

## 9. What You'll Do in the Lab

1. **Explore** the MPD manifest and content structure
2. **Observe** the ABR algorithm making decisions in real-time via Grafana dashboard
3. **Impair** the network using traffic shaping presets and watch the client adapt
4. **Capture** traffic and analyze it in Wireshark
5. **Analyze** ABR algorithm parameters and predict behavior changes
6. **Measure** QoE metrics using Prometheus/Grafana monitoring

---

## 10. Preparation Checklist

Before the lab, ensure you understand:

- [ ] The difference between progressive download and adaptive streaming
- [ ] What an MPD manifest contains and why
- [ ] The basic idea of ABR (measure throughput, select quality)
- [ ] Why buffer level matters for streaming quality
- [ ] What `tc` does (traffic shaping)

**Recommended additional reading:**

- DASH-IF Guidelines: https://dashif.org/guidelines/
- "A Buffer-Based Approach to Rate Adaptation" (BBA paper)
- Wireshark HTTP analysis basics

---

## Glossary

| Term | Definition |
|------|------------|
| **ABR** | Adaptive Bitrate — algorithm that selects quality level |
| **Buffer** | Client-side storage of downloaded video not yet played |
| **CDN** | Content Delivery Network — distributed servers for content |
| **DASH** | Dynamic Adaptive Streaming over HTTP (MPEG standard) |
| **HLS** | HTTP Live Streaming (Apple standard) |
| **Manifest** | File describing available streams (MPD or M3U8) |
| **MPD** | Media Presentation Description — DASH manifest format |
| **QoE** | Quality of Experience — user-perceived quality |
| **Rebuffering** | Playback stall while waiting for data |
| **Representation** | One quality variant in DASH |
| **Segment** | Small chunk of video (typically 2-10 seconds) |
| **Throughput** | Achieved data transfer rate |

---

*Pre-lab reading for HTTP Adaptive Streaming Lab v2.0 - Grafana Edition*
