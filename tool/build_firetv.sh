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
# Entrypoint is production by default; override with ENTRY=development. This
# project uses separate main_*.dart entrypoints (-t), NOT Gradle product
# flavors, so --flavor must not be passed.
set -euo pipefail

MODE="${1:-apk}"
ENTRY="${ENTRY:-production}"
IMPELLER="${IMPELLER:-true}"
TARGET="lib/main_${ENTRY}.dart"

BUILD_ARGS=(--release "-t" "${TARGET}")

# Forward the Impeller toggle to Gradle's manifest placeholder. Not all Flutter
# versions forward -P through `flutter build`; if the toggle appears ignored,
# set `enableImpeller` directly in android/gradle.properties instead.
BUILD_ARGS+=("--android-project-arg=enableImpeller=${IMPELLER}")

echo "→ entry=${ENTRY}  impeller=${IMPELLER}  mode=${MODE}"

case "${MODE}" in
  apk)
    flutter build apk --split-per-abi "${BUILD_ARGS[@]}"
    echo "APKs: build/app/outputs/flutter-apk/"
    ;;
  bundle)
    flutter build appbundle "${BUILD_ARGS[@]}"
    echo "AAB: build/app/outputs/bundle/"
    ;;
  *)
    echo "Unknown mode '${MODE}' (want: apk | bundle)" >&2
    exit 2
    ;;
esac
