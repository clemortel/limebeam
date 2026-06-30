import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:get_it/get_it.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/src/infrastructure/epg_repository.dart";
import "package:iptv_epg/src/models/epg_entry.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
IEpgRepository epgRepository(Ref ref) =>
    GetIt.instance<IEpgRepository>();

/// Loads all EPG entries from cache as the custom [AsyncState]. keepAlive —
/// EPG is large and shared across the live list.
@Riverpod(keepAlive: true)
class EpgNotifier extends _$EpgNotifier {
  @override
  AsyncState<IList<EpgEntry>> build() {
    _fetch();
    return const AsyncState<IList<EpgEntry>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<EpgEntry>> result =
        await ref.read(epgRepositoryProvider).getAll();
    state = result.fold(
      (Failures failure) => AsyncState<IList<EpgEntry>>.error(failure),
      (IList<EpgEntry> entries) =>
          AsyncState<IList<EpgEntry>>.success(entries),
    );
  }

  Future<void> refresh() => _fetch();
}

/// Current programme per EPG channel id at [at]. Used by the live list for
/// now-playing titles + progress. Empty when EPG is unavailable.
@riverpod
Map<String, EpgEntry> epgNow(Ref ref, DateTime at) {
  final AsyncState<IList<EpgEntry>> state = ref.watch(epgProvider);
  final IList<EpgEntry> entries = switch (state) {
    AsyncSuccess<IList<EpgEntry>>(:final IList<EpgEntry> data) => data,
    _ => const IListConst<EpgEntry>(<EpgEntry>[]),
  };
  final Map<String, EpgEntry> now = <String, EpgEntry>{};
  for (final EpgEntry e in entries) {
    if (e.isLiveAt(at)) now[e.channelId] = e;
  }
  return now;
}
