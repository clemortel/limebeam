# AirPlay — remaining native work

The AirPlay **route picker** is fully wired:

- `AirPlayRoutePicker` / `AirPlayRouteTile` (`iptv_cast`) embed the native
  `AVRoutePickerView` via `UiKitView` (iOS only).
- `ios/Runner/AirPlayRoutePickerFactory.swift` registers the platform view
  (id `limebeam/airplay_route_picker`) in `AppDelegate`.
- The picker appears at the top of the cast device sheet on iOS.

## What is NOT done (and why it needs a device)

Tapping the picker routes the **system audio/video route** — but video only
*streams* to the Apple TV when the media is playing through an **`AVPlayer`**.
This app's local engine is **media_kit (libmpv)**, which does not follow the
AirPlay route. So true AirPlay video requires an iOS playback engine backed by
`AVPlayer` instead of libmpv for any stream the user may AirPlay.

### The seam

`src/domain/playback_controller.dart` already defines the engine contract
(`open` / `play` / `pause` / `seek` / `position` / `status` / `dispose`). The
remaining work:

1. Extract today's media_kit usage from the `PlaybackController` notifier
   (`src/riverpods/player_controller.dart`) into a `MediaKitEngine`
   implementing that contract (default on Android / desktop).
2. Add an `AvPlayerEngine` (iOS) backed by a native `AVPlayer` exposed through a
   platform view + method channel, implementing the same contract.
3. Have the notifier select the engine by platform (`AvPlayerEngine` on iOS so
   AirPlay routes video) and delegate to it — all timers/state stay in the
   notifier, which already calls through a `_player` seam.

This is intentionally deferred: it is a native, device-tested change and must
not be done blind. Until then, the picker routes system audio and Chromecast
(`flutter_chrome_cast`) is the working "cast to TV" path on both platforms.

Caveat: test on iOS 18.4+ for the known AirPlay regression
(flutter/flutter#167924).
