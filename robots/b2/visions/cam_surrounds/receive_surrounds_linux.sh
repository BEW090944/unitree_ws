#!/bin/bash
set -euo pipefail

# ---- Config (MULTICAST VERSION - LINUX) ----
MULTICAST_IP="239.1.1.1"  # Must match Orin's multicast group
PORTS=(5000 5001 5002 5003)
WIDTH=1920
HEIGHT=1536
FPS=30

# [Decoder Options for Linux]
# - avdec_h264: Software decoder (works everywhere, uses CPU)
# - vaapih264dec: Intel/AMD hardware acceleration (requires gstreamer1.0-vaapi)
# - nvh264dec: NVIDIA hardware acceleration (requires gstreamer1.0-plugins-bad with NVDEC)
DECODER="${DECODER:-avdec_h264}"
LATENCY="${LATENCY:-80}"   # rtpjitterbuffer latency (ms)

# [Video Sink Options for Linux]
# - autovideosink: Auto-detect best sink
# - xvimagesink: X11 (most compatible)
# - glimagesink: OpenGL (better performance)
VIDEOSINK="${VIDEOSINK:-autovideosink}"

mk_branch () {
  local port=$1 idx=$2
  echo "udpsrc multicast-group=$MULTICAST_IP auto-multicast=true port=$port caps=\"application/x-rtp,media=video,encoding-name=H264,clock-rate=90000,payload=96\" !
        rtpjitterbuffer latency=$LATENCY drop-on-latency=true do-lost=true !
        rtph264depay ! h264parse !
        $DECODER !
        videoconvert ! videoscale ! videorate !
        video/x-raw,format=I420,width=$WIDTH,height=$HEIGHT,framerate=${FPS}/1 !
        queue max-size-buffers=120 leaky=downstream !
        comp.sink_$idx"
}

# --- Main Pipeline ---
gst-launch-1.0 -e \
  compositor name=comp background=black start-time-selection=first \
    sink_0::xpos=0 sink_0::ypos=0 \
    sink_1::xpos=$WIDTH sink_1::ypos=0 \
    sink_2::xpos=0 sink_2::ypos=$HEIGHT \
    sink_3::xpos=$WIDTH sink_3::ypos=$HEIGHT \
  ! videoconvert ! fpsdisplaysink video-sink=$VIDEOSINK sync=false text-overlay=false \
  $(mk_branch ${PORTS[0]} 0) \
  $(mk_branch ${PORTS[1]} 1) \
  $(mk_branch ${PORTS[2]} 2) \
  $(mk_branch ${PORTS[3]} 3)
