#!/usr/bin/env python3
import argparse
import json
from collections import Counter

def analyze_telemetry(events):
    if not events:
        print("No telemetry data to analyze")
        return

    bitrates = [e["bandwidth_kbps"] for e in events]
    throughputs = [e["measured_throughput_kbps"] for e in events]
    switches = sum(1 for e in events if e.get("quality_switch"))
    up_switches = sum(1 for e in events if e.get("switch_direction") == "up")
    down_switches = sum(1 for e in events if e.get("switch_direction") == "down")

    print("=" * 70)
    print("HAS LAB TELEMETRY ANALYSIS")
    print("=" * 70)
    print("\nSESSION SUMMARY")
    print("-" * 40)
    print(f"Total segments:        {len(events)}")
    print(f"Quality switches:      {switches} (↑{up_switches} ↓{down_switches})")
    print(f"Avg throughput:        {sum(throughputs)/len(throughputs):.1f} kbps")
    print(f"Avg bitrate played:    {sum(bitrates)/len(bitrates):.1f} kbps")
    print(f"Bitrate range:         {min(bitrates)} - {max(bitrates)} kbps")

    print("\nBITRATE DISTRIBUTION")
    print("-" * 40)
    counter = Counter(bitrates)
    max_count = max(counter.values())
    for br in sorted(counter.keys()):
        count = counter[br]
        bar = "█" * int(30 * count / max_count)
        pct = 100 * count / len(bitrates)
        print(f"{br:5d} kbps: {bar:30s} {count:3d} ({pct:5.1f}%)")

    print("\nBITRATE TIMELINE")
    print("-" * 40)
    print(f"{'Segment':>7}  {'Bitrate':>10}  {'Throughput':>12}   Event")
    print("-" * 40)
    for e in events:
        seg = e["segment_number"]
        br = e["bandwidth_kbps"]
        tp = e["measured_throughput_kbps"]
        event = ""
        if e.get("switch_direction") == "up":
            event = "⬆  QUALITY UP"
        elif e.get("switch_direction") == "down":
            event = "⬇  QUALITY DOWN"
        print(f"{seg:>7}  {br:>7} kbps  {tp:>9.1f} kbps {event}")
        if event:
            print("-" * 40)

    # ASCII chart
    print("\nTHROUGHPUT VS BITRATE CHART")
    print("-" * 70)
    print("Legend: █ = selected bitrate, ░ = measured throughput\n")
    max_val = max(max(throughputs), max(bitrates))
    width = 51

    for e in events:
        seg = e["segment_number"]
        br = e["bandwidth_kbps"]
        tp = e["measured_throughput_kbps"]
        br_pos = int((br / max_val) * (width - 1))
        tp_pos = int((tp / max_val) * (width - 1))
        line = [" "] * width
        line[min(tp_pos, width-1)] = "░"
        line[min(br_pos, width-1)] = "█"
        switch = ""
        if e.get("switch_direction") == "up":
            switch = "↑"
        elif e.get("switch_direction") == "down":
            switch = "↓"
        print(f"{seg:3d} |{''.join(line)}| {switch}")

    print(f"    +{'-' * 51}+")
    print(f"    0{' ' * 23}{int(max_val // 2)}{' ' * 22}{int(max_val)} kbps")
    print()


def main():
    parser = argparse.ArgumentParser(description="Analyze HAS lab telemetry")
    parser.add_argument("telemetry_file", nargs="?", default="logs/telemetry.jsonl")
    args = parser.parse_args()

    events = []
    with open(args.telemetry_file, "r") as f:
        for line in f:
            if line.strip():
                events.append(json.loads(line))

    analyze_telemetry(events)


if __name__ == "__main__":
    main()
