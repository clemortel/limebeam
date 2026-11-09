import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_downloads/iptv_downloads.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "downloads_source_sync.g.dart";

/// Keeps offline downloads in step with the saved playlist sources.
///
/// - A source that disappears from the list (deleted in Settings) loses its
///   downloads: tasks cancelled, the plugin's stored copy of them purged,
///   files and records deleted. Trap: the plugin keeps the credentialed URL
///   of every task, so a deleted source must not leave one behind. Deleting
///   the credentials from secure storage does not reach it.
/// - Records written before downloads were scoped are given to the source
///   that is active when the list first loads.
///
/// Lives here rather than in iptv_auth because it is the app that knows both
/// features; watched once from the root widget.
@Riverpod(keepAlive: true)
void downloadsSourceSync(Ref ref) {
  ref.listen<AsyncState<IList<Source>>>(
    sourcesProvider,
    (AsyncState<IList<Source>>? _, AsyncState<IList<Source>> next) {
      if (next case AsyncSuccess<IList<Source>>(:final IList<Source> data)) {
        _sync(ref, data);
      }
    },
    fireImmediately: true,
  );
}

Future<void> _sync(Ref ref, IList<Source> sources) async {
  final IDownloadsRepository repository = ref.read(downloadsRepositoryProvider);
  final String? active = ref.read(activeSourceStoreProvider).sourceId;
  if (active != null) await repository.adoptLegacy(active);
  await repository.retainSources(
    sources.map((Source s) => s.id).toISet(),
  );
}
