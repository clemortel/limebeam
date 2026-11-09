import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../infrastructure/source_repository.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
ISourceRepository sourceRepository(Ref ref) =>
    GetIt.instance<ISourceRepository>();

/// Exposes the in-memory active-source holder (set on connect / hydrate).
@Riverpod(keepAlive: true)
ActiveSourceStore activeSourceStore(Ref ref) =>
    GetIt.instance<ActiveSourceStore>();

/// The active provider client, used to build playable stream URLs. Null when
/// no source is connected.
@riverpod
IPlaylistSource? activePlaylistSource(Ref ref) {
  final SourceConfig? config = ref.watch(activeSourceStoreProvider).config;
  if (config == null) return null;
  return GetIt.instance<PlaylistSourceFactory>().create(config);
}

/// Providers holding per-source data (favorites, watch sessions…) that live
/// in features this package must not depend on. The app root overrides it;
/// every one is invalidated as soon as the active source changes.
@Riverpod(keepAlive: true)
IList<ProviderOrFamily> sourceScopedProviders(Ref ref) =>
    IList<ProviderOrFamily>();
