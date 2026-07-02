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
# shellcheck disable=SC2064
trap "kill ${LOGCAT_PID} 2>/dev/null || true; rm -f ${LOG_FILE}" EXIT

sleep "${SECONDS_TO_SAMPLE}"
kill "${LOGCAT_PID}" 2>/dev/null || true

SLOW_FRAMES=$(grep -c "SLOW FRAME" "${LOG_FILE}" || true)
# Sum the "Dropping N frames" counters MediaCodec prints cumulatively.
DROPPED=$(grep -oE "Dropping [0-9]+ frames" "${LOG_FILE}" | grep -oE "[0-9]+" | sort -n | tail -1 || echo 0)
WORST_BUILD=$(grep -oE "build=[0-9]+ms" "${LOG_FILE}" | grep -oE "[0-9]+" | sort -n | tail -1 || echo 0)

echo
echo "== Results (${SECONDS_TO_SAMPLE}s) =="
echo "SLOW FRAME log lines : ${SLOW_FRAMES}"
echo "Worst build spike    : ${WORST_BUILD} ms"
echo "Max dropped-frames   : ${DROPPED}"
echo
echo "== gfxinfo jank summary =="
adb shell dumpsys gfxinfo "${PKG}" | grep -E \
  "Total frames rendered|Janky frames|50th|90th|95th|99th|Number Missed Vsync" || true
