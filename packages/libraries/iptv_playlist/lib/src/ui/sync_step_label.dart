import "package:iptv_l10n/iptv_l10n.dart";

import "../riverpods/sync_progress.dart";

/// Localized status line of a sync step, shared by the connecting screen and
/// the Sources settings.
extension SyncStepLabel on SyncStep {
  String label(AppLocalizations l) => switch (this) {
        SyncStep.idle || SyncStep.connecting => l.onboardingSyncConnecting,
        SyncStep.live => l.onboardingSyncLive,
        SyncStep.vod => l.onboardingSyncVod,
        SyncStep.series => l.onboardingSyncSeries,
        SyncStep.epg => l.onboardingSyncEpg,
        SyncStep.done => l.onboardingSyncDone,
        SyncStep.failed => l.onboardingSyncFailed,
      };
}
