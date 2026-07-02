# Fire TV / Android TV playback performance

Tooling for measuring and A/B-testing player smoothness on real hardware.
**Always measure in `--release` on a real Stick** — debug/JIT numbers are noise.

## Background

The player janked on Fire TV with `SLOW FRAME build=100–216ms` (Dart/UI build
thread) while `raster` stayed at 3–7ms — i.e. the GPU was fine; the widget tree
was rebuilding too much. Root cause: `PlaybackController` pushed a new
`PlayerUiState` on every libmpv position tick, and `PlayerView` watched the
whole state, so the entire overlay (gradient scrim, bars, seek bar, TV track
panel) rebuilt several times a second even while hidden.

Fixes shipped:

- **Throttle** position/buffer → state to ~4 Hz (`_kPositionEmitInterval`).
- **Structure-only watch**: `PlayerView` watches a `.select`ed `_PlayerVm`
  (no position/duration/buffer); the seek bar/labels live inside `_Controls`,
  which watches the live state itself.
- **Unmount when hidden**: `_ControlsLayer` drops the controls subtree after the
  fade-out, so hidden playback rebuilds ~nothing.
- **Video isolation**: the engine's `Video`/platform view is built once and
  wrapped in a `RepaintBoundary`, so overlay repaints never touch the texture.

## Measure

```bash
# Play a live channel or VOD, leave the overlay HIDDEN, then:
tool/perf/measure_playback.sh 60          # 60s sample, default package
```

Reports SLOW FRAME count, worst `build=` spike, max dropped frames, and the
`gfxinfo` jank percentiles. Target after the fix: near-zero SLOW FRAME during
hidden-overlay playback and no `MediaCodecLogger Dropping frames`.

## Impeller vs Skia A/B

Impeller is **on by default** (`enableImpeller=true` in `android/gradle.properties`)
because it avoids Skia's EGLImage raster cost on the Stick's PowerVR GE8300.
But Impeller's Vulkan backend (used on API-29+ Vulkan devices like the Fire TV
Stick **4K Max**) does **not** natively support the SurfaceTexture path
media_kit renders through (flutter/flutter#180831 — still open), so on those
devices Skia can win. Decide per device, with data.

```bash
# A — Impeller ON (default)
tool/build_firetv.sh apk
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
tool/perf/measure_playback.sh 60

# B — Impeller OFF (Skia)
IMPELLER=false tool/build_firetv.sh apk
adb install -r build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
tool/perf/measure_playback.sh 60
```

Keep whichever gives the lower 99th-percentile frame time and fewer dropped
frames. Run it on **both** the 1st-gen Stick 4K (Impeller→GLES) and the 4K Max
(Impeller→Vulkan) — the winner may differ. Then set the default in
`android/gradle.properties` accordingly and revert any local override.

> Do the A/B **after** confirming the rebuild fixes above are in the build, so
> the renderer comparison isn't confounded by Dart-side jank.
