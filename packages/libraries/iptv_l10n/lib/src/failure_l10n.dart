import "package:iptv_core/iptv_core.dart";

import "../l10n/app_localizations.dart";

/// Maps a [Failures] to a localized, user-facing message. Replaces the old
/// English-only `computeErrorMessage()` — call sites pass `AppLocalizations`.
extension FailuresL10n on Failures {
  String localized(AppLocalizations l) => switch (this) {
        NetworkError() => l.errNetwork,
        ServerError(:final int code) => l.errServer(code),
        NotFound() => l.errNotFound,
        Unexpected() => l.errUnexpected,
        InvalidPlaylist() => l.errInvalidPlaylist,
        PortalAuthFailure() => l.errPortalAuth,
        StreamUnavailable() => l.errStreamUnavailable,
        EpgUnavailable() => l.errEpgUnavailable,
        CastUnavailable() => l.errCastUnavailable,
        CastConnectionFailed() => l.errCastConnection,
      };
}
