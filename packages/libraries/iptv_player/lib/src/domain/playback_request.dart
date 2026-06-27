import "package:freezed_annotation/freezed_annotation.dart";

part "playback_request.freezed.dart";

/// What kind of content a [PlaybackRequest] points at. Drives overlay shape
/// (live = no seek bar; episode/movie = full timeline).
enum PlaybackKind { live, movie, episode }

/// A single playable item handed to the player. Self-contained: carries the
/// already-built stream URL + the metadata the overlay needs, so `iptv_player`
/// never imports the feature libraries (Channel/Movie/Episode).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class PlaybackRequest with _$PlaybackRequest {
  const PlaybackRequest._();

  const factory PlaybackRequest({
    required String contentId,
    required PlaybackKind kind,
    required String title,
    required String url,
    String? subtitle,
    String? posterUrl,
    // Alternate URL for engines that need HLS (iOS AVPlayer over AirPlay, which
    // cannot decode raw MPEG-TS). Null = use [url] everywhere.
    String? externalUrl,
    @Default("") String containerExtension,
    @Default(Duration.zero) Duration startAt,
  }) = _PlaybackRequest;

  /// Live streams are non-DVR: no scrubbing, "● DIRECT" badge only.
  bool get isLive => kind == PlaybackKind.live;
}
