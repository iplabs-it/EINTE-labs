#!/usr/bin/env python3
import json
import sys

for line in sys.stdin:
    try:
        e = json.loads(line.strip())
        ts = e.get("timestamp", "")[:19].split("T")[1] if "T" in e.get("timestamp", "") else ""
        seg = e.get("segment_number", 0)
        bw = e.get("bandwidth_kbps", 0)
        tp = e.get("measured_throughput_kbps", 0)
        buf = e.get("buffer_level_segments", 0)
        sw = "⬆" if e.get("switch_direction") == "up" else ("⬇" if e.get("switch_direction") == "down" else "")
        print(f"{ts} | Seg {seg:3d} | {bw:5d} kbps | throughput: {tp:7.1f} kbps | buffer: {buf} {sw}")
    except:
        pass
