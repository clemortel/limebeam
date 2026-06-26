import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/source.dart";
import "providers.dart";

part "sources_notifier.g.dart";

/// Saved-source list for Réglages (§4.6). Long-lived cache.
@Riverpod(keepAlive: true)
class SourcesNotifier extends _$SourcesNotifier {
  @override
  AsyncState<IList<Source>> build() {
    _load();
    return const AsyncState<IList<Source>>.loading();
  }

  Future<void> _load() async {
    final IList<Source> sources =
        await ref.read(sourceRepositoryProvider).getSources();
    state = AsyncState<IList<Source>>.success(sources);
  }

  Future<void> refresh() => _load();

  Future<void> delete(String id) async {
    await ref.read(sourceRepositoryProvider).deleteSource(id);
    await _load();
  }
}
