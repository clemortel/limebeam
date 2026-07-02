#!/usr/bin/env bash
#
# Release builds for Fire TV / Android TV.
#
# Per media_kit's guidance, ship per-ABI APKs (smaller download, faster install
# and load on the Stick) rather than a fat APK. Fire TV Sticks are arm:
# older/1st-gen 4K are armeabi-v7a, 4K Max / newer are arm64-v8a.
#
# We do NOT force ABI splits in Gradle because that breaks `flutter run`'s
# single-APK expectation during development; instead we split here at the
# `flutter build` layer, which only affects release artifacts.
#
# Usage:
#   tool/build_firetv.sh            # split-per-abi release APKs
#   tool/build_firetv.sh bundle     # single app bundle (Play; not Amazon)
#   IMPELLER=false tool/build_firetv.sh   # build with Impeller off (A/B)
#
# Flavor is production by default; override with FLAVOR=development.
set -euo pipefail

MODE="${1:-apk}"
FLAVOR="${FLAVOR:-production}"
IMPELLER="${IMPELLER:-true}"
TARGET="lib/main_${FLAVOR}.dart"

GRADLE_ARGS=(--release "--flavor=${FLAVOR}" "-t" "${TARGET}")

# Forward the Impeller toggle to Gradle (manifest placeholder). Flutter passes
# unknown -P properties through to the Android build.
GRADLE_ARGS+=("-PenableImpeller=${IMPELLER}")

echo "→ flavor=${FLAVOR}  impeller=${IMPELLER}  mode=${MODE}"

case "${MODE}" in
  apk)
    flutter build apk --split-per-abi "${GRADLE_ARGS[@]}"
    echo "APKs: build/app/outputs/flutter-apk/"
    ;;
  bundle)
    flutter build appbundle "${GRADLE_ARGS[@]}"
    echo "AAB: build/app/outputs/bundle/"
    ;;
  *)
    echo "Unknown mode '${MODE}' (want: apk | bundle)" >&2
    exit 2
    ;;
esac
