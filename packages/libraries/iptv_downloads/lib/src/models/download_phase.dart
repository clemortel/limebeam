import "package:freezed_annotation/freezed_annotation.dart";

import "download_failure_reason.dart";

part "download_phase.freezed.dart";
part "download_phase.g.dart";

/// Where one episode stands. A union so a finished download cannot carry a
/// progress value, nor a running one a failure.
@freezed
sealed class DownloadPhase with _$DownloadPhase {
  const factory DownloadPhase.queued() = DownloadQueued;

  /// [progress] is 0..1. Transient: never written on each tick.
  const factory DownloadPhase.running(double progress) = DownloadRunning;

  /// Stopped by the user; the native layer keeps the partial file.
  const factory DownloadPhase.paused() = DownloadPaused;
  const factory DownloadPhase.completed() = DownloadCompleted;
  const factory DownloadPhase.failed({
    @Default(DownloadFailureReason.unknown) DownloadFailureReason reason,
  }) = DownloadFailed;

  factory DownloadPhase.fromJson(Map<String, dynamic> json) =>
      _$DownloadPhaseFromJson(json);
}
