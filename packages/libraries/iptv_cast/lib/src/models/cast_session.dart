import "package:freezed_annotation/freezed_annotation.dart";

import "cast_device.dart";

part "cast_session.freezed.dart";

/// Snapshot of the active remote-playback session on a [CastDevice].
///
/// Mirrors the fields the player overlay needs to act as a remote: the remote
/// clock ([position] / [duration]) and transport flags. A null [device] means
/// no session is active (local playback). Not JSON-serialised — it is a live
/// view of the cast session, never persisted.
@freezed
sealed class CastSession with _$CastSession {
  const factory CastSession({
    CastDevice? device,
    @Default(Duration.zero) Duration position,
    @Default(Duration.zero) Duration duration,
    @Default(false) bool playing,
    @Default(false) bool buffering,
  }) = _CastSession;

  const CastSession._();

  /// True while a remote device owns playback.
  bool get isActive => device != null;
}
