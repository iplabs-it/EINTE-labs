#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB_DIR="${SCRIPT_DIR}/.."
CONTENT_DIR="${LAB_DIR}/content/stream"

mkdir -p "$CONTENT_DIR"

echo "Downloading Big Buck Bunny sample..."
if [[ ! -f "${LAB_DIR}/content/bbb_source.mp4" ]]; then
    docker run --rm -v "${LAB_DIR}/content:/content" --security-opt seccomp=unconfined \
        linuxserver/ffmpeg:latest \
        -y -f lavfi -i "testsrc=duration=10:size=1920x1080:rate=30" \
        -f lavfi -i "sine=frequency=440:duration=10" \
        -c:v libx264 -preset fast -c:a aac \
        /content/source_10s.mp4

    docker run --rm -v "${LAB_DIR}/content:/content" --security-opt seccomp=unconfined \
        linuxserver/ffmpeg:latest \
        -y -stream_loop 59 -i /content/source_10s.mp4 \
        -c copy -t 600 /content/bbb_source.mp4
fi

echo "Encoding DASH content at multiple bitrates..."
docker run --rm -v "${LAB_DIR}/content:/content" -v "${CONTENT_DIR}:/output" \
    --security-opt seccomp=unconfined \
    linuxserver/ffmpeg:latest \
    -y -i /content/bbb_source.mp4 \
    -map 0:v -map 0:v -map 0:v -map 0:v -map 0:a \
    -c:v libx264 -preset fast \
    -b:v:0 400k -s:v:0 640x360 \
    -b:v:1 800k -s:v:1 854x480 \
    -b:v:2 1200k -s:v:2 1280x720 \
    -b:v:3 2500k -s:v:3 1920x1080 \
    -c:a aac -b:a 128k \
    -f dash \
    -seg_duration 2 \
    -use_timeline 1 \
    -use_template 1 \
    -init_seg_name 'init-$RepresentationID$.m4s' \
    -media_seg_name '$RepresentationID$-$Number%05d$.m4s' \
    /output/manifest.mpd

echo "DASH content ready in ${CONTENT_DIR}"
ls -la "$CONTENT_DIR"
