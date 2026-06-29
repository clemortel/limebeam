# Amazon Appstore (Fire TV) media assets

Generated from the LimeBeam brand kit (`files/`) by `build_assets.sh`.
Re-run that script after any brand change.

## Field → file mapping

### Tablet assets
| Amazon field | Spec | File |
|---|---|---|
| Icon | 512×512 PNG (transparency) | `tablet_icon_512.png` |
| Icon | 114×114 PNG (transparency) | `tablet_icon_114.png` |
| Screenshots (min 3) | 1280×720 PNG | `screenshots/tablet/*.png` |
| Promotional image (optional) | 1024×500 PNG/JPG | `promo_1024x500.png` |

### Fire TV assets
| Amazon field | Spec | File |
|---|---|---|
| App icon | 1280×720 PNG (no transparency) | `firetv_icon_1280x720.png` |
| Screenshots (min 3) | 1920×1080 PNG, landscape | `screenshots/firetv/*.png` |
| Background image | 1920×1080 PNG (no transparency) | `firetv_background_1920x1080.png` |
| Featured content logo (optional) | 640×260 PNG | `featured_logo_640x260.png` |
| Featured content background (optional) | 1920×720 PNG (no transparency) | `featured_background_1920x720.png` |

## Screenshots — IMPORTANT (provisional)

The three screenshots (Live / Settings / Search) are real captures of the TV
10-foot UI from the Android TV emulator, but:

- **They are upscaled.** The emulator panel is 1280×720, so the Fire TV set
  (`screenshots/firetv/`) was upscaled 1.5× to 1920×1080. Quality is acceptable
  but soft. For crisp 1080p, recapture on a real Fire TV device.
- **Poster screens are missing** (Home rails, Movies/Series grids, detail
  pages). The emulator currently has no DNS, so the demo posters
  (`picsum.photos`) fail to load and render as broken images. Recapture those
  once images load — on a real Fire TV, or an emulator launched with working
  DNS (`emulator @<avd> -dns-server 8.8.8.8`).

Aim for 4–6 screenshots that show posters/content for a stronger listing.

### Recapture recipe (adb)
With a Fire TV / Android TV device or emulator connected:
```bash
# Navigate the app to the screen you want (D-pad / remote), then:
adb exec-out screencap -p > shot.png
# Drive navigation headlessly if needed:
#   19=UP 20=DOWN 21=LEFT 22=RIGHT 23=OK/CENTER 4=BACK
adb shell input keyevent 20
```
Fire TV needs 1920×1080 (capture on a 1080p device, or upscale:
`sips -z 1080 1920 shot.png --out shot_1080.png`).

## Regenerate the graphic assets
```bash
store_assets/amazon/build_assets.sh
```
Needs `rsvg-convert` + `sips` (macOS). Outputs land in this folder.
