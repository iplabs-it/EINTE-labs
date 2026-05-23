#!/usr/bin/env python3
"""
Simple DASH client with Adaptive Bitrate (ABR) selection and telemetry.
Includes Prometheus metrics endpoint for Grafana edition.
"""

import argparse
import json
import logging
import math
import re
import sys
import time
import threading
from dataclasses import dataclass, asdict
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path
from typing import Optional
from urllib.parse import urljoin
from xml.etree import ElementTree as ET

import requests

DASH_NS_URI = "{urn:mpeg:dash:schema:mpd:2011}"

# Global metrics for Prometheus
METRICS = {
    "current_bitrate_kbps": 0,
    "measured_throughput_kbps": 0.0,
    "buffer_level_segments": 0,
    "segment_number": 0,
    "download_time_ms": 0.0,
    "quality_switches_total": 0,
    "quality_switches_up": 0,
    "quality_switches_down": 0,
    "segments_downloaded_total": 0,
}
METRICS_LOCK = threading.Lock()


class MetricsHandler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/metrics":
            self.send_response(200)
            self.send_header("Content-Type", "text/plain")
            self.end_headers()
            with METRICS_LOCK:
                output = [
                    f"has_current_bitrate_kbps {METRICS['current_bitrate_kbps']}",
                    f"has_measured_throughput_kbps {METRICS['measured_throughput_kbps']:.1f}",
                    f"has_buffer_level_segments {METRICS['buffer_level_segments']}",
                    f"has_segment_number {METRICS['segment_number']}",
                    f"has_download_time_ms {METRICS['download_time_ms']:.1f}",
                    f"has_quality_switches_total {METRICS['quality_switches_total']}",
                    f"has_quality_switches_up {METRICS['quality_switches_up']}",
                    f"has_quality_switches_down {METRICS['quality_switches_down']}",
                    f"has_segments_downloaded_total {METRICS['segments_downloaded_total']}",
                ]
                self.wfile.write("\n".join(output).encode())
        else:
            self.send_response(404)
            self.end_headers()

    def log_message(self, format, *args):
        pass


def start_metrics_server(port=8000):
    server = HTTPServer(("0.0.0.0", port), MetricsHandler)
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()
    return server


@dataclass
class Representation:
    id: str
    bandwidth: int
    width: int
    height: int
    base_url: str


@dataclass
class TelemetryEvent:
    timestamp: str
    event_type: str
    segment_number: int
    representation_id: str
    bandwidth_kbps: int
    measured_throughput_kbps: float
    download_time_ms: float
    segment_size_bytes: int
    buffer_level_segments: int
    quality_switch: bool
    switch_direction: Optional[str] = None


class DASHClient:
    def __init__(self, mpd_url: str, output_dir: Path, buffer_target: int = 3, throughput_safety_factor: float = 0.7):
        self.mpd_url = mpd_url
        self.output_dir = output_dir
        self.buffer_target = buffer_target
        self.safety_factor = throughput_safety_factor
        self.session = requests.Session()
        self.representations: list[Representation] = []
        self.current_rep_index: int = 0
        self.segment_template: str = ""
        self.segment_duration: float = 0
        self.total_segments: int = 0
        self.telemetry: list[TelemetryEvent] = []
        self.throughput_history: list[float] = []
        self.throughput_window = 5
        self.buffer_level = 0
        self.current_segment = 1
        self.logger = logging.getLogger("DASHClient")
        self._setup_output_dir()

    def _setup_output_dir(self):
        self.output_dir.mkdir(parents=True, exist_ok=True)
        self.telemetry_file = self.output_dir / "telemetry.jsonl"

    def _parse_duration(self, duration_str: str) -> float:
        if not duration_str.startswith("PT"):
            return 0.0
        duration_str = duration_str[2:]
        total_seconds = 0.0
        if "H" in duration_str:
            h_idx = duration_str.index("H")
            total_seconds += float(duration_str[:h_idx]) * 3600
            duration_str = duration_str[h_idx + 1:]
        if "M" in duration_str:
            m_idx = duration_str.index("M")
            total_seconds += float(duration_str[:m_idx]) * 60
            duration_str = duration_str[m_idx + 1:]
        if "S" in duration_str:
            s_idx = duration_str.index("S")
            total_seconds += float(duration_str[:s_idx])
        return total_seconds

    def parse_mpd(self) -> bool:
        try:
            response = self.session.get(self.mpd_url, timeout=10)
            response.raise_for_status()
        except requests.RequestException as e:
            self.logger.error(f"Failed to fetch MPD: {e}")
            return False

        root = ET.fromstring(response.content)
        ns = DASH_NS_URI
        duration_str = root.get("mediaPresentationDuration", "PT0S")
        self.logger.info(f"Media duration: {duration_str}")
        media_duration = self._parse_duration(duration_str)

        for adaptation_set in root.findall(f".//{ns}AdaptationSet"):
            content_type = adaptation_set.get("contentType", "")
            mime_type = adaptation_set.get("mimeType", "")
            if content_type != "video" and "video" not in mime_type:
                continue

            for rep in adaptation_set.findall(f"{ns}Representation"):
                rep_id = rep.get("id", "")
                seg_template = rep.find(f"{ns}SegmentTemplate")
                if seg_template is None:
                    seg_template = adaptation_set.find(f"{ns}SegmentTemplate")

                if seg_template is not None and not self.segment_template:
                    self.segment_template = seg_template.get("media", "")
                    timescale = int(seg_template.get("timescale", 1))
                    timeline = seg_template.find(f"{ns}SegmentTimeline")
                    if timeline is not None:
                        total_duration = 0
                        segment_count = 0
                        for s_elem in timeline.findall(f"{ns}S"):
                            d = int(s_elem.get("d", 0))
                            r = int(s_elem.get("r", 0))
                            segment_count += 1 + r
                            total_duration += d * (1 + r)
                        self.total_segments = segment_count
                        self.segment_duration = (total_duration / segment_count) / timescale if segment_count > 0 else 2.0
                        self.logger.info(f"Timeline mode: {self.total_segments} segments, ~{self.segment_duration:.1f}s each")
                    else:
                        duration = int(seg_template.get("duration", 1))
                        self.segment_duration = duration / timescale
                        if media_duration > 0 and self.segment_duration > 0:
                            self.total_segments = math.ceil(media_duration / self.segment_duration)

                self.representations.append(Representation(
                    id=rep_id,
                    bandwidth=int(rep.get("bandwidth", 0)),
                    width=int(rep.get("width", 0)),
                    height=int(rep.get("height", 0)),
                    base_url=rep_id,
                ))

        self.representations.sort(key=lambda r: r.bandwidth)
        self.logger.info(f"Found {len(self.representations)} representations:")
        for i, rep in enumerate(self.representations):
            self.logger.info(f"  [{i}] {rep.id}: {rep.bandwidth // 1000} kbps ({rep.width}x{rep.height})")
        return len(self.representations) > 0

    def estimate_throughput(self) -> float:
        if not self.throughput_history:
            return 500.0
        values = self.throughput_history[-self.throughput_window:]
        harmonic_mean = len(values) / sum(1 / v for v in values if v > 0)
        return harmonic_mean * self.safety_factor

    def select_representation(self) -> int:
        throughput_kbps = self.estimate_throughput()
        throughput_bps = throughput_kbps * 1000
        selected = 0
        for i, rep in enumerate(self.representations):
            if rep.bandwidth <= throughput_bps:
                selected = i
            else:
                break
        return selected

    def download_segment(self, segment_num: int, rep_index: int) -> Optional[tuple[bytes, float, float]]:
        rep = self.representations[rep_index]
        segment_url = self.segment_template.replace("$RepresentationID$", rep.id)
        number_match = re.search(r'\$Number%(\d+)d\$', segment_url)
        if number_match:
            width = int(number_match.group(1))
            segment_url = re.sub(r'\$Number%\d+d\$', str(segment_num).zfill(width), segment_url)
        else:
            segment_url = segment_url.replace("$Number$", str(segment_num))
        segment_url = urljoin(self.mpd_url, segment_url)

        start_time = time.perf_counter()
        try:
            response = self.session.get(segment_url, timeout=30)
            response.raise_for_status()
        except requests.RequestException as e:
            self.logger.error(f"Failed to download segment {segment_num}: {e}")
            return None

        download_time = time.perf_counter() - start_time
        download_time_ms = download_time * 1000
        segment_size = len(response.content)
        throughput_kbps = (segment_size * 8 / 1000) / download_time if download_time > 0 else 0
        return response.content, download_time_ms, throughput_kbps

    def record_telemetry(self, segment_num: int, rep_index: int, throughput_kbps: float,
                         download_time_ms: float, segment_size: int, quality_switch: bool,
                         switch_direction: Optional[str]):
        rep = self.representations[rep_index]
        event = TelemetryEvent(
            timestamp=datetime.utcnow().isoformat(),
            event_type="segment_download",
            segment_number=segment_num,
            representation_id=rep.id,
            bandwidth_kbps=rep.bandwidth // 1000,
            measured_throughput_kbps=round(throughput_kbps, 2),
            download_time_ms=round(download_time_ms, 2),
            segment_size_bytes=segment_size,
            buffer_level_segments=self.buffer_level,
            quality_switch=quality_switch,
            switch_direction=switch_direction,
        )
        self.telemetry.append(event)
        with open(self.telemetry_file, "a") as f:
            f.write(json.dumps(asdict(event)) + "\n")

        switch_marker = ""
        if quality_switch:
            switch_marker = " ⬆ UP" if switch_direction == "up" else " ⬇ DOWN"
        self.logger.info(
            f"Seg {segment_num:3d} | {rep.bandwidth // 1000:5d} kbps | "
            f"throughput: {throughput_kbps:7.1f} kbps | buffer: {self.buffer_level} seg | "
            f"time: {download_time_ms:6.1f} ms{switch_marker}"
        )

        # Update Prometheus metrics
        with METRICS_LOCK:
            METRICS["current_bitrate_kbps"] = rep.bandwidth // 1000
            METRICS["measured_throughput_kbps"] = throughput_kbps
            METRICS["buffer_level_segments"] = self.buffer_level
            METRICS["segment_number"] = segment_num
            METRICS["download_time_ms"] = download_time_ms
            METRICS["segments_downloaded_total"] += 1
            if quality_switch:
                METRICS["quality_switches_total"] += 1
                if switch_direction == "up":
                    METRICS["quality_switches_up"] += 1
                elif switch_direction == "down":
                    METRICS["quality_switches_down"] += 1

    def run(self, max_segments: Optional[int] = None):
        self.logger.info(f"Starting DASH streaming from {self.mpd_url}")
        if not self.parse_mpd():
            self.logger.error("Failed to parse MPD, exiting")
            return

        self.current_rep_index = 0
        segments_to_download = min(max_segments, self.total_segments) if max_segments else self.total_segments

        self.logger.info(f"\n{'=' * 70}")
        self.logger.info("Starting playback simulation...")
        self.logger.info(f"{'=' * 70}\n")

        for seg_num in range(1, segments_to_download + 1):
            self.current_segment = seg_num
            new_rep_index = self.select_representation()
            quality_switch = new_rep_index != self.current_rep_index
            switch_direction = None
            if quality_switch:
                switch_direction = "up" if new_rep_index > self.current_rep_index else "down"
            self.current_rep_index = new_rep_index

            result = self.download_segment(seg_num, self.current_rep_index)
            if result is None:
                continue

            data, download_time_ms, throughput_kbps = result
            self.throughput_history.append(throughput_kbps)
            if self.buffer_level < 5:
                self.buffer_level += 1

            self.record_telemetry(seg_num, self.current_rep_index, throughput_kbps,
                                  download_time_ms, len(data), quality_switch, switch_direction)

            download_time_sec = download_time_ms / 1000
            if download_time_sec < self.segment_duration and self.buffer_level >= self.buffer_target:
                pace_delay = (self.segment_duration - download_time_sec) * 0.3
                time.sleep(pace_delay)

        self.print_summary()

    def print_summary(self):
        if not self.telemetry:
            return
        switches = sum(1 for t in self.telemetry if t.quality_switch)
        up_switches = sum(1 for t in self.telemetry if t.switch_direction == "up")
        down_switches = sum(1 for t in self.telemetry if t.switch_direction == "down")
        avg_throughput = sum(t.measured_throughput_kbps for t in self.telemetry) / len(self.telemetry)
        avg_bitrate = sum(t.bandwidth_kbps for t in self.telemetry) / len(self.telemetry)

        self.logger.info(f"\n{'=' * 70}")
        self.logger.info("SESSION SUMMARY")
        self.logger.info(f"{'=' * 70}")
        self.logger.info(f"Total segments:      {len(self.telemetry)}")
        self.logger.info(f"Quality switches:    {switches} (↑{up_switches} ↓{down_switches})")
        self.logger.info(f"Avg throughput:      {avg_throughput:.1f} kbps")
        self.logger.info(f"Avg bitrate played:  {avg_bitrate:.1f} kbps")
        self.logger.info(f"Telemetry saved to:  {self.telemetry_file}")
        self.logger.info(f"{'=' * 70}\n")


def main():
    parser = argparse.ArgumentParser(description="DASH streaming client with telemetry")
    parser.add_argument("--mpd", default="http://10.0.1.2/stream/manifest.mpd", help="URL to MPD manifest")
    parser.add_argument("--output", default="/app/logs", help="Output directory for telemetry")
    parser.add_argument("--segments", type=int, default=None, help="Number of segments to download")
    parser.add_argument("--loop", action="store_true", help="Loop playback continuously")
    parser.add_argument("--metrics", action="store_true", help="Enable Prometheus metrics on port 8000")
    parser.add_argument("--metrics-port", type=int, default=8000, help="Prometheus metrics port")
    parser.add_argument("--verbose", "-v", action="store_true", help="Verbose output")
    args = parser.parse_args()

    log_level = logging.DEBUG if args.verbose else logging.INFO
    logging.basicConfig(level=log_level, format="%(asctime)s [%(levelname)s] %(message)s", datefmt="%H:%M:%S")

    if args.metrics:
        start_metrics_server(args.metrics_port)
        logging.info(f"Prometheus metrics at http://0.0.0.0:{args.metrics_port}/metrics")

    client = DASHClient(mpd_url=args.mpd, output_dir=Path(args.output))

    try:
        if args.loop:
            loop_count = 0
            while True:
                loop_count += 1
                client.logger.info(f"\n>>> LOOP {loop_count} <<<\n")
                client.current_segment = 1
                client.buffer_level = 0
                client.representations = []
                client.segment_template = ""
                client.throughput_history = []
                client.current_rep_index = 0
                client.run(max_segments=args.segments)
        else:
            client.run(max_segments=args.segments)
    except KeyboardInterrupt:
        client.print_summary()
        sys.exit(0)


if __name__ == "__main__":
    main()
