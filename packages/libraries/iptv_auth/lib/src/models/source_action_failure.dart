import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

part "source_action_failure.freezed.dart";

/// Why a source action (switch, delete, rename) did not happen. `Failures`
/// has no case for "a sync is running" or "blank name", so the view maps
/// these to dedicated copy instead of the generic error.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class SourceActionFailure with _$SourceActionFailure {
  /// A sync is in flight: the switch was refused, nothing changed.
  const factory SourceActionFailure.syncInProgress() = SyncInProgress;

  const factory SourceActionFailure.blankName() = BlankName;

  const factory SourceActionFailure.failed(Failures failure) = ActionFailed;
}

/// What deleting a source left behind; the caller reacts without reading
/// any provider after the await.
enum DeleteOutcome {
  /// Deleted; another source is (or stays) active.
  deleted,

  /// Deleted the last one: the app has no active source anymore.
  noSourceLeft,
}
