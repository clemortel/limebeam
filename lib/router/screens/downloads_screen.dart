import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_l10n/iptv_l10n.dart";

import "../../download_launch.dart";
import "../../player_launch.dart";

/// Offline library. Reads local records only, so it works in airplane mode.
@RoutePage()
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DownloadsView(
      onPlay: (DownloadRecord record) =>
          ref.openDownloadedEpisode(context, record),
      onRetry: (DownloadRecord record) async {
        final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
        final String message =
            AppLocalizations.of(context).downloadsRetryNoSource;
        final bool started = await ref.retryDownload(record);
        if (!started) {
          messenger.showSnackBar(SnackBar(content: Text(message)));
        }
      },
    );
  }
}
