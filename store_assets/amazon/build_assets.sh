#!/usr/bin/env bash
#
# Generates the Amazon Appstore (Fire TV + tablet) media assets from the
# LimeBeam brand kit, at the exact dimensions Amazon requires.
#
#   store_assets/amazon/build_assets.sh
#
# Needs: rsvg-convert + sips (macOS). Outputs land in this directory.
#
# Amazon spec → output:
#   Tablet icon 512x512 PNG (alpha)        → tablet_icon_512.png
#   Tablet icon 114x114 PNG (alpha)        → tablet_icon_114.png
#   Fire TV app icon 1280x720 PNG (opaque) → firetv_icon_1280x720.png
#   Fire TV background 1920x1080 (opaque)  → firetv_background_1920x1080.png
#   Featured logo 640x260 PNG (alpha)      → featured_logo_640x260.png
#   Featured background 1920x720 (opaque)  → featured_background_1920x720.png
#   Promo 1024x500 (landscape)             → promo_1024x500.png
#
# Screenshots are NOT generated here — they must be real captures (see the
# README in this folder).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
OUT="$ROOT/store_assets/amazon"
SRC="$OUT/_src"
BRAND="$ROOT/files"
mkdir -p "$SRC"

# librsvg only loads <image> resources from the SVG's own directory, so copy
# the brand rasters next to the wrapper SVGs and reference them by bare name.
cp "$BRAND/limebeam_lockup_dark.png" "$SRC/lockup.png"
cp "$BRAND/limebeam_mark_512.png" "$SRC/mark.png"

BG="#0B0C0E"

# Render an SVG file to a PNG at an exact pixel size.
render() { rsvg-convert -w "$2" -h "$3" "$1" -o "$4"; }

# Strip the alpha channel (PNG→JPG→PNG) for "no transparency" assets, leaving an
# opaque RGB PNG. Avoids needing ImageMagick.
strip_alpha() {
  local png="$1"
  sips -s format jpeg "$png" --out "$SRC/_flat.jpg" >/dev/null
  sips -s format png "$SRC/_flat.jpg" --out "$png" >/dev/null
}

# --- Tablet icons (transparency kept) — straight downscale of the app icon ---
sips -z 512 512 "$BRAND/limebeam_appicon_1024.png" --out "$OUT/tablet_icon_512.png" >/dev/null
sips -z 114 114 "$BRAND/limebeam_appicon_1024.png" --out "$OUT/tablet_icon_114.png" >/dev/null

# --- Fire TV app icon 1280x720 (dark bg + centered lockup) ---
# lockup is 1520x440 (≈3.45:1); 720 wide → ~208 tall, centered.
cat > "$SRC/firetv_icon.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1280" height="720" viewBox="0 0 1280 720">
  <rect width="1280" height="720" fill="$BG"/>
  <image x="280" y="256" width="720" height="208" xlink:href="lockup.png"/>
</svg>
SVG
render "$SRC/firetv_icon.svg" 1280 720 "$OUT/firetv_icon_1280x720.png"
strip_alpha "$OUT/firetv_icon_1280x720.png"

# --- Fire TV background 1920x1080 (dark radial + faint mark watermark) ---
cat > "$SRC/firetv_bg.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1920" height="1080" viewBox="0 0 1920 1080">
  <defs>
    <radialGradient id="g" cx="50%" cy="36%" r="80%">
      <stop offset="0" stop-color="#16181D"/>
      <stop offset="1" stop-color="$BG"/>
    </radialGradient>
  </defs>
  <rect width="1920" height="1080" fill="url(#g)"/>
  <image opacity="0.06" x="610" y="180" width="700" height="700" xlink:href="mark.png"/>
</svg>
SVG
render "$SRC/firetv_bg.svg" 1920 1080 "$OUT/firetv_background_1920x1080.png"
strip_alpha "$OUT/firetv_background_1920x1080.png"

# --- Featured content logo 640x260 (lockup on transparent) ---
# 600 wide → ~174 tall, centered.
cat > "$SRC/featured_logo.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="640" height="260" viewBox="0 0 640 260">
  <image x="20" y="43" width="600" height="174" xlink:href="lockup.png"/>
</svg>
SVG
render "$SRC/featured_logo.svg" 640 260 "$OUT/featured_logo_640x260.png"

# --- Featured content background 1920x720 (dark gradient) ---
cat > "$SRC/featured_bg.svg" <<SVG
<svg xmlns="http://www.w3.org/2000/svg" xmlns:xlink="http://www.w3.org/1999/xlink" width="1920" height="720" viewBox="0 0 1920 720">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#181B20"/>
      <stop offset="1" stop-color="$BG"/>
    </linearGradient>
  </defs>
  <rect width="1920" height="720" fill="url(#g)"/>
  <image opacity="0.06" x="1380" y="120" width="480" height="480" xlink:href="mark.png"/>
</svg>
SVG
render "$SRC/featured_bg.svg" 1920 720 "$OUT/featured_background_1920x720.png"
strip_alpha "$OUT/featured_background_1920x720.png"

# --- Promo 1024x500 — the brand feature graphic is already this exact size ---
render "$BRAND/limebeam_feature_graphic.svg" 1024 500 "$OUT/promo_1024x500.png"

rm -rf "$SRC"

echo "Generated assets:"
for f in tablet_icon_512 tablet_icon_114 firetv_icon_1280x720 \
         firetv_background_1920x1080 featured_logo_640x260 \
         featured_background_1920x720 promo_1024x500; do
  p="$OUT/$f.png"
  dims="$(sips -g pixelWidth -g pixelHeight -g hasAlpha "$p" 2>/dev/null \
          | awk '/pixelWidth/{w=$2}/pixelHeight/{h=$2}/hasAlpha/{a=$2}END{print w"x"h" alpha="a}')"
  printf "  %-34s %s\n" "$f.png" "$dims"
done
