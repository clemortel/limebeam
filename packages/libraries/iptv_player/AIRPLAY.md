# iOS playback engine & AirPlay

## How it works now

iOS plays through a **native `AVPlayer`** (not media_kit/libmpv), so AirPlay
streams **video** — libmpv can only ever route audio. The engine is selected by
platform in `PlaybackController.start`:

- **iOS** → `AvPlayerEngine` (`src/infrastructure/av_player_engine.dart`) over a
  method channel (`limebeam/avplayer`) + event channel
  (`limebeam/avplayer/events`), with an `AVPlayerLayer` platform view
  (`limebeam/avplayer_view`). Native side: `ios/Runner/AVPlayerEngine.swift`,
  registered in `AppDelegate`.
- **Android / desktop** → `MediaKitEngine`
  (`src/infrastructure/media_kit_engine.dart`), unchanged libmpv pipeline.

Both implement `PlaybackEngine` (`src/domain/playback_engine.dart`); the notifier
delegates open/play/pause/seek/volume and consumes the engine's state streams +
`buildView()`. No engine type leaks past that boundary.

AirPlay itself is handled entirely by iOS: the native `AVRoutePickerView` (the
"AirPlay" row in the cast sheet) routes the `AVPlayer` to the Apple TV. The Swift
engine sets `allowsExternalPlayback = true` and
`usesExternalPlaybackWhileExternalScreenIsActive = true`. The app's transport
controls keep working because they drive the same `AVPlayer`. (Chromecast is the
separate `castTo` handoff path; AirPlay does not go through it.)

## Must be verified on a real device

The native engine cannot be exercised in a headless/CI environment — test on
hardware:

1. Local iOS playback (HLS live + VOD): play/pause/seek/volume, resume-position,
   next-episode autoplay, buffering states.
2. AirPlay to an Apple TV: pick AirPlay from the cast sheet, confirm **video**
   (not just audio) on the TV and that controls drive it. The local screen is
   black during external playback — expected for a raw `AVPlayerLayer`.
3. iOS 18.4+ AirPlay regression (flutter/flutter#167924).

## Notes / possible follow-ups

- Exotic codecs that libmpv handled on iOS but `AVPlayer` may not (some
  MKV/H.265/odd audio). Most IPTV is HLS/MP4 and plays fine.
- The media_kit pods still link on iOS (deps unchanged) but are unused there;
  removing them from the iOS build is an optional cleanup.
- A nicer local "Playing on <TV>" placeholder during AirPlay could replace the
  black `AVPlayerLayer` (cosmetic).
