#!/usr/bin/env bash
#
# LimeBeam release helper — one command to ship a build to both stores.
#
#   bin/release.sh            # iOS (TestFlight) + Android (Play internal)
#   bin/release.sh ios        # iOS only
#   bin/release.sh android    # Android only
#   bin/release.sh --no-deploy   # codegen + analyze only (dry run)
#
# Pipeline: build_runner (every package that needs it) → dart analyze →
# fastlane `beta` per platform (signed build, auto-incremented build number,
# upload). Auth comes from the in-repo fastlane credentials (.p8 / service
# account). Requires `bundle install` once in ios/ and android/.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

TARGET="all"
DEPLOY=1
for arg in "$@"; do
  case "$arg" in
    ios|android|all) TARGET="$arg" ;;
    --no-deploy) DEPLOY=0 ;;
    *) echo "Unknown arg: $arg" >&2; exit 2 ;;
  esac
done

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

if [[ "$DEPLOY" -eq 0 ]]; then
  echo "✓ Dry run complete (codegen + analyze). Skipping deploy."
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
  echo "▶ Android → Play internal…"
  (cd android && bundle exec fastlane android beta)
fi

echo "✓ Release pipeline finished for: $TARGET"
