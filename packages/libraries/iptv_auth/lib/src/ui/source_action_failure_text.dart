import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";

import "../models/source_action_failure.dart";

/// Localized message for a refused or failed source action.
extension SourceActionFailureText on SourceActionFailure {
  String text(AppLocalizations l) => switch (this) {
        SyncInProgress() => l.sourcesSyncBusy,
        BlankName() => l.sourcesRenameBlank,
        ActionFailed(:final Failures failure) => failure.localized(l),
      };
}
