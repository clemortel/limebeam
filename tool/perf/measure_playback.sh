#!/usr/bin/env bash
#
# Capture playback smoothness on a connected Fire TV / Android TV over adb.
#
# Measures the two signals that matter for the player jank:
#   1. Flutter "SLOW FRAME" lines (from bootstrap.dart's frame logger) — the
#      Dart/UI build-thread spikes.
#   2. "Dropping N frames" from MediaCodecLogger — decoded frames the compositor
#      couldn't present in time.
#   3. `dumpsys gfxinfo` jank stats (janky frames %, 90th/95th/99th percentile).
#
# Run it while a channel/VOD is actively playing with the OVERLAY HIDDEN (the
# normal watching state this optimization targets). Compare the before/after and
# the Impeller-on/off numbers (see README.md).
#
# Usage:
#   tool/perf/measure_playback.sh [seconds] [package]
# Defaults: 60 seconds, com.limebeam.app
set -euo pipefail

SECONDS_TO_SAMPLE="${1:-60}"
PKG="${2:-com.limebeam.app}"

command -v adb >/dev/null || { echo "adb not found on PATH" >&2; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "no adb device connected" >&2; exit 1; }

echo "== Device =="
adb shell getprop ro.product.model
adb shell getprop ro.build.version.sdk | sed 's/^/API level: /'
echo

echo "== Resetting counters, sampling ${SECONDS_TO_SAMPLE}s (play something now) =="
adb shell dumpsys gfxinfo "${PKG}" reset >/dev/null 2>&1 || true
adb logcat -c

LOG_FILE="$(mktemp -t limebeam_perf.XXXXXX)"
adb logcat -v time > "${LOG_FILE}" &
LOGCAT_PID=$!
# Drop it from the job table so the shell doesn't print "Terminated: 15".
disown "${LOGCAT_PID}" 2>/dev/null || true
# shellcheck disable=SC2064
trap "kill ${LOGCAT_PID} 2>/dev/null || true; rm -f ${LOG_FILE}" EXIT

sleep "${SECONDS_TO_SAMPLE}"
kill "${LOGCAT_PID}" 2>/dev/null || true
wait "${LOGCAT_PID}" 2>/dev/null || true

# Flutter build-thread spikes (from bootstrap.dart's frame logger; runs in
# release too). Should be ~0 while the overlay is hidden after the perf fix.
SLOW_FRAMES=$(grep -c "SLOW FRAME" "${LOG_FILE}" || true)
WORST_BUILD=$(grep -oE "build=[0-9]+ms" "${LOG_FILE}" | grep -oE "[0-9]+" | sort -n | tail -1 || echo 0)
WORST_RASTER=$(grep -oE "raster=[0-9]+ms" "${LOG_FILE}" | grep -oE "[0-9]+" | sort -n | tail -1 || echo 0)
# MediaCodec prints a cumulative "Dropping N frames"; the last one is the total.
DROPPED=$(grep -oE "Dropping [0-9]+ frames" "${LOG_FILE}" | grep -oE "[0-9]+" | sort -n | tail -1 || echo 0)
DROPS_PER_SEC=$(( DROPPED / SECONDS_TO_SAMPLE ))
# media_kit prints the texture size on (re)size; tells us the stream resolution.
RESIZE_COUNT=$(grep -c "VideoOutput.Resize" "${LOG_FILE}" || true)
VIDEO_SIZE=$(grep -oE "\{height: [0-9]+, width: [0-9]+" "${LOG_FILE}" | tail -1 | tr -d '{' || echo "")
[ -z "${VIDEO_SIZE}" ] && VIDEO_SIZE="unknown"
# Decoder codec + most-common WxH from MediaCodec/OMX/ACodec native logs.
CODEC=$(grep -ohiE "video/(avc|hevc|x-vnd\.on2\.vp9|av01|mp4v)" "${LOG_FILE}" | head -1 || true)
[ -z "${CODEC}" ] && CODEC="unknown"
RES_GUESS=$(grep -ohE "[0-9]{3,4} ?x ?[0-9]{3,4}" "${LOG_FILE}" | tr -d ' ' | sort | uniq -c | sort -rn | head -1 || true)
[ -z "${RES_GUESS}" ] && RES_GUESS="unknown"
HW=$(grep -qiE "OMX\.|c2\.[a-z]+\.(avc|hevc|vp9).*decoder|\.HW\." "${LOG_FILE}" && echo "hardware" || echo "software?")

echo
echo "== Results (${SECONDS_TO_SAMPLE}s) =="
echo "Flutter SLOW FRAME lines : ${SLOW_FRAMES}   (target: ~0 with overlay hidden)"
echo "Worst build spike        : ${WORST_BUILD} ms   (UI thread)"
echo "Worst raster spike       : ${WORST_RASTER} ms   (GPU/compositor)"
echo "Dropped VIDEO frames     : ${DROPPED}  (~${DROPS_PER_SEC}/s)   <- live stutter"
echo "Decoder codec            : ${CODEC}  (${HW})"
echo "Decoded resolution       : ${RES_GUESS}   (3840x2160 = 4K)"
echo "Video texture size       : ${VIDEO_SIZE}"
echo "Texture resizes          : ${RESIZE_COUNT}   (>1 during playback = churn)"
echo
echo "NOTE: 'dumpsys gfxinfo' cannot see Impeller frames (reports 0 rendered),"
echo "so it is omitted here. SLOW FRAME + dropped-frame counts are the signals."
echo "Dropped video frames are a DECODE/RENDER cost, not a Flutter-UI cost."
