import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:iptv_series/iptv_series.dart";

/// Turns series episodes into download requests for the active source.
extension DownloadLaunch on WidgetRef {
  /// Queues [episodes] of [season]. No-op without an active source.
  ///
  /// Trap: the built URL embeds the Xtream password; it goes straight into
  /// the request and is never logged nor shown.
  Future<void> downloadEpisodes(
    Series series,
    Season season,
    IList<Episode> episodes,
  ) async {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null || episodes.isEmpty) return;
    final IList<DownloadRequest> requests = episodes
        .map(
          (Episode e) => DownloadRequest(
            contentId: e.id,
            seriesId: series.id,
            seriesTitle: series.name,
            seasonNumber: season.number,
            episodeNumber: e.episodeNum,
            title: e.title,
            containerExtension: e.containerExtension,
            url: source.buildSeriesUrl(e.id, e.containerExtension),
            seriesCoverUrl: series.coverUrl ?? "",
            duration: e.duration,
          ),
        )
        .toIList();
    await read(downloadsProvider.notifier).enqueue(requests);
  }

  /// Restarts a failed [record] from zero. Returns false without an active
  /// source: the URL is not stored, it is rebuilt from the source here.
  ///
  /// Trap: the rebuilt URL embeds the Xtream password; never log it.
  Future<bool> retryDownload(DownloadRecord record) async {
    final IPlaylistSource? source = read(activePlaylistSourceProvider);
    if (source == null) return false;
    final DownloadRequest request = DownloadRequest(
      contentId: record.contentId,
      seriesId: record.seriesId,
      seriesTitle: record.seriesTitle,
      seasonNumber: record.seasonNumber,
      episodeNumber: record.episodeNumber,
      title: record.title,
      containerExtension: record.containerExtension,
      url: source.buildSeriesUrl(
        record.contentId,
        record.containerExtension,
      ),
      seriesCoverUrl: record.seriesCoverUrl,
      duration: record.duration,
    );
    await read(downloadsProvider.notifier)
        .enqueue(<DownloadRequest>[request].toIList());
    return true;
  }
}
