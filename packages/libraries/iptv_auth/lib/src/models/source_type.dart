import "package:json_annotation/json_annotation.dart";

/// Provider kind for a saved source.
///
/// [demo] is a transient onboarding kind only — it is never persisted. Demo
/// sources are saved as [m3u] (they go through `addM3uSource`); the value just
/// lets the connecting screen know to seed the bundled demo playlist.
enum SourceType {
  @JsonValue("xtream")
  xtream,
  @JsonValue("m3u")
  m3u,
  @JsonValue("demo")
  demo,
}
