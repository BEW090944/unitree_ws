#!/bin/bash
set -euo pipefail

# ---- Config ----
PORTS=(5000 5001 5002 5003)
WIDTH=1920
HEIGHT=1536
FPS=30
# ใช้ avdec_h264 ถ้าซีพียูไหว; ถ้าเป็น Intel ลอง vaapih264dec; ถ้า NVIDIA ลอง nvh264dec
DECODER="${DECODER:-avdec_h264}"
LATENCY="${LATENCY:-80}"   # rtpjitterbuffer latency (ms)

mk_branch () {
  local port=$1 idx=$2
  echo "udpsrc port=$port caps=\"application/x-rtp,media=video,encoding-name=H264,clock-rate=90000,payload=96\" !
        rtpjitterbuffer latency=$LATENCY drop-on-latency=true do-lost=true !
        rtph264depay ! h264parse !
        $DECODER !
        videoconvert ! videoscale ! videorate !
        video/x-raw,format=I420,width=$WIDTH,height=$HEIGHT,framerate=${FPS}/1 !
        queue max-size-buffers=120 leaky=downstream !
        comp.sink_$idx"
}

gst-launch-1.0 -e \
  compositor name=comp background=black start-time-selection=first \
    sink_0::xpos=0 sink_0::ypos=0 \
    sink_1::xpos=$WIDTH sink_1::ypos=0 \
    sink_2::xpos=0 sink_2::ypos=$HEIGHT \
    sink_3::xpos=$WIDTH sink_3::ypos=$HEIGHT \
  ! videoconvert ! fpsdisplaysink sync=false text-overlay=false \
  $(mk_branch ${PORTS[0]} 0) \
  $(mk_branch ${PORTS[1]} 1) \
  $(mk_branch ${PORTS[2]} 2) \
  $(mk_branch ${PORTS[3]} 3)
