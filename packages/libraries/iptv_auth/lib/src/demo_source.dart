/// Bundled demo source so a first-time user (or an app-store reviewer) can
/// explore the app without any credentials. The rich offline catalog (live +
/// VOD + series, legally-public sample content) is served by the demo client in
/// `iptv_api`; here we only expose its display name.
library;

/// Display name of the demo source as saved in the sources list.
const String kDemoSourceName = "Démo LimeBeam";
