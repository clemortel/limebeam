import "package:auto_route/auto_route.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_downloads/iptv_downloads.dart";

import "../../player_launch.dart";

/// Offline library. Reads local records only, so it works in airplane mode.
@RoutePage()
class DownloadsScreen extends ConsumerWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.toastDownloadFailures(context);
    return DownloadsView(
      sourceId: ref.watch(activeSourceStoreProvider).sourceId,
      onPlay: (DownloadRecord record) =>
          ref.openDownloadedEpisode(context, record),
    );
  }
}
