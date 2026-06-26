import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

part "sync_progress.freezed.dart";

/// Sequential steps of an initial source sync, shown on the connecting screen
/// (§4.1.6) as real sub-steps.
enum SyncStep { idle, connecting, live, vod, series, epg, done, failed }

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

  /// Localized status line for the current step.
  String get statusLabel => switch (step) {
        SyncStep.idle || SyncStep.connecting => "Connexion à la source…",
        SyncStep.live => "Récupération des chaînes…",
        SyncStep.vod => "Récupération des films…",
        SyncStep.series => "Récupération des séries…",
        SyncStep.epg => "Chargement de l'EPG…",
        SyncStep.done => "Terminé",
        SyncStep.failed => "Échec de la synchronisation",
      };
}
