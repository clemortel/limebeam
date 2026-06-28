#!/usr/bin/env bash
#
# LimeBeam release helper — one command to ship a build to the stores.
#
#   bin/release.sh            # iOS (TestFlight) + Play (AAB) + Fire TV (APK)
#   bin/release.sh ios        # iOS only
#   bin/release.sh android    # Android only — Play AAB (phone + Android TV)
#   bin/release.sh amazon     # Fire TV / Amazon Appstore — release APK only
#   bin/release.sh --no-deploy   # codegen + analyze only (dry run)
#
# Pipeline: build_runner (every package that needs it) → dart analyze →
# TV-manifest check → fastlane `beta` per platform (signed build,
# auto-incremented build number, upload). Auth comes from the in-repo fastlane
# credentials (.p8 / service account). Requires `bundle install` once in ios/
# and android/.
#
# Form factors:
#   • Google Play  — ONE App Bundle serves phone, tablet AND Android TV. The
#     leanback manifest entries make Play offer it on TV once the app is opted
#     into the "Android TV" form factor in Play Console (one-time setup).
#   • Amazon (Fire TV) — a separate store that takes an APK, not an AAB. The
#     `amazon` target builds that APK; upload is manual in the Amazon console
#     (no fastlane lane / API credentials are configured).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="all"
DEPLOY=1
for arg in "$@"; do
  case "$arg" in
    ios|android|amazon|all) TARGET="$arg" ;;
    --no-deploy) DEPLOY=0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

MANIFEST="android/app/src/main/AndroidManifest.xml"

# Fail fast if a regression silently drops the Android TV / Fire TV entries —
# the same AAB/APK would then no longer be accepted on TV form factors.
verify_tv_manifest() {
  echo "▶ Verifying Android TV manifest entries…"
  local missing=0
  grep -q "android.software.leanback" "$MANIFEST" || { echo "  ✗ missing uses-feature android.software.leanback"; missing=1; }
  grep -q "LEANBACK_LAUNCHER" "$MANIFEST" || { echo "  ✗ missing LEANBACK_LAUNCHER category"; missing=1; }
  grep -q "android:banner" "$MANIFEST" || { echo "  ✗ missing android:banner"; missing=1; }
  if [[ "$missing" -ne 0 ]]; then
    echo "✗ TV manifest check failed — see $MANIFEST" >&2
    exit 1
  fi
  echo "  ✓ leanback + LEANBACK_LAUNCHER + banner present"
}

echo "▶ Codegen (build_runner) in every package that declares it…"
while IFS= read -r pubspec; do
  dir="$(dirname "$pubspec")"
  if grep -q "build_runner" "$pubspec"; then
    echo "  • ${dir#./}"
    (cd "$dir" && dart run build_runner build --delete-conflicting-outputs >/dev/null)
  fi
done < <(find . -name pubspec.yaml -not -path "*/build/*" -not -path "*/.dart_tool/*")

echo "▶ Analyze (release is aborted on any error)…"
dart analyze .

# TV entries are part of every Android artifact (Play AAB + Amazon APK).
if [[ "$TARGET" == "all" || "$TARGET" == "android" || "$TARGET" == "amazon" ]]; then
  verify_tv_manifest
fi

if [[ "$DEPLOY" -eq 0 ]]; then
  echo "✓ Dry run complete (codegen + analyze + TV check). Skipping deploy."
  exit 0
fi

if [[ "$TARGET" == "all" || "$TARGET" == "ios" ]]; then
  echo "▶ iOS → TestFlight…"
  # Pre-empt the Xcode 'accessing build database … disk I/O error' from stale
  # DerivedData caches.
  rm -rf ~/Library/Developer/Xcode/DerivedData/Runner-* 2>/dev/null || true
  (cd ios && bundle exec fastlane ios beta)
fi

if [[ "$TARGET" == "all" || "$TARGET" == "android" ]]; then
  echo "▶ Android → Play internal (one AAB: phone + tablet + Android TV)…"
  (cd android && bundle exec fastlane android beta)
fi

if [[ "$TARGET" == "all" || "$TARGET" == "amazon" ]]; then
  echo "▶ Fire TV / Amazon Appstore → release APK…"
  # Amazon takes an APK (not an AAB). Universal APK so the single artifact runs
  # on every Fire TV ABI. Signed with the release keystore via build.gradle.kts.
  flutter build apk --release
  APK="build/app/outputs/flutter-apk/app-release.apk"
  if [[ ! -f "$APK" ]]; then
    echo "✗ No release APK at $APK — did the build run?" >&2
    exit 1
  fi
  echo "  ✓ Built $APK"
  echo "  → Upload it manually at https://developer.amazon.com (Apps & Services"
  echo "    → your app → Upload APK), then submit for review."
fi

echo "✓ Release pipeline finished for: $TARGET"
