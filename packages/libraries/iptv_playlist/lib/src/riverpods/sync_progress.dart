import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

part "sync_progress.freezed.dart";

/// Sequential steps of an initial source sync, shown on the connecting screen
/// (§4.1.6) as real sub-steps.
enum SyncStep { idle, connecting, live, vod, series, epg, done, failed }

/// Number of visible sync steps: live, vod, series, epg.
const int kSyncStepCount = 4;

/// Progress of the eager post-connect sync. Counts feed the success summary.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SyncProgress with _$SyncProgress {
  const SyncProgress._();

  const factory SyncProgress({
    @Default(SyncStep.idle) SyncStep step,
    @Default(0) int channels,
    @Default(0) int movies,
    @Default(0) int series,
    @Default(false) bool epgLoaded,
    Failures? failure,
  }) = _SyncProgress;

  bool get isDone => step == SyncStep.done;
  bool get isFailed => step == SyncStep.failed;

  /// 1-based position of the running step among [kSyncStepCount] (0 before
  /// the first). Drives the "Step 2 of 4" line and the progress bar.
  int get stepNumber => switch (step) {
        SyncStep.idle || SyncStep.connecting || SyncStep.failed => 0,
        SyncStep.live => 1,
        SyncStep.vod => 2,
        SyncStep.series => 3,
        SyncStep.epg => 4,
        SyncStep.done => kSyncStepCount,
      };
}
