/// Bundled demo source — a small playlist of free, legal, public test streams
/// so a first-time user (or an app-store reviewer) can see the app work without
/// entering any credentials. The app ships no real content; these are official
/// HLS test/sample streams.
///
/// The `asset:` scheme is resolved by the HTTP layer via `rootBundle`, so the
/// playlist travels inside the app bundle — no third-party host to go down.
library;

/// Display name of the demo source as saved in the sources list.
const String kDemoSourceName = "Démo LimeBeam";

/// Bundled demo playlist, addressed through the `asset:` scheme understood by
/// the HTTP service. Path is the Flutter package-asset key for `iptv_auth`.
const String kDemoM3uUrl = "asset:packages/iptv_auth/assets/demo_playlist.m3u";
