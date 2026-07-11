import "package:freezed_annotation/freezed_annotation.dart";

import "content_kind.dart";

part "watch_session.freezed.dart";
part "watch_session.g.dart";

/// A resume point for a VOD item (movie / episode). [id] + [containerExtension]
/// let the app rebuild the playable URL from the active source on resume.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class WatchSession with _$WatchSession {
  const WatchSession._();

  const factory WatchSession({
    required String id,
    required ContentKind kind,
    required String title,
    required String containerExtension,
    required int positionSeconds,
    required int durationSeconds,
    required int updatedAtMillis,
    String? subtitle,
    String? posterUrl,
    // For episodes: the parent series id, so resume can rebuild the whole
    // season queue (next/previous episode) instead of a lone item.
    String? seriesId,
  }) = _WatchSession;

  factory WatchSession.fromJson(Map<String, dynamic> json) =>
      _$WatchSessionFromJson(json);

  /// 0..1 elapsed fraction for the resume bar.
  double get fraction =>
      durationSeconds > 0 ? (positionSeconds / durationSeconds).clamp(0, 1) : 0;

  /// Stable identity across kinds.
  String get key => "${kind.name}_$id";
}
