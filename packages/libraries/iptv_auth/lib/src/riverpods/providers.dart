import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../infrastructure/source_repository.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
ISourceRepository sourceRepository(SourceRepositoryRef ref) =>
    GetIt.instance<ISourceRepository>();

/// Exposes the in-memory active-source holder (set on connect / hydrate).
@Riverpod(keepAlive: true)
ActiveSourceStore activeSourceStore(ActiveSourceStoreRef ref) =>
    GetIt.instance<ActiveSourceStore>();

/// The active provider client, used to build playable stream URLs. Null when
/// no source is connected.
@riverpod
IPlaylistSource? activePlaylistSource(ActivePlaylistSourceRef ref) {
  final SourceConfig? config = ref.watch(activeSourceStoreProvider).config;
  if (config == null) return null;
  return GetIt.instance<PlaylistSourceFactory>().create(config);
}
