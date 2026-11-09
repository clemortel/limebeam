import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/form_field_issue.dart";
import "../models/source.dart";
import "m3u_form_state.dart";
import "providers.dart";
import "sources_notifier.dart";

part "add_m3u_source_notifier.g.dart";

/// Drives the M3U onboarding form: validation + submission. Kept alive so the
/// values survive form → connecting navigation.
@Riverpod(keepAlive: true)
class AddM3uSourceNotifier extends _$AddM3uSourceNotifier {
  @override
  M3uFormState build() => const M3uFormState();

  void reset() => state = const M3uFormState();

  void setName(String value) => state = state.copyWith(name: value);

  /// Pre-fills the playlist address from a pasted link.
  void applyLink({required String url}) => setUrl(url);

  void setUrl(String value) => state = state.copyWith(
        url: value,
        urlError: validateUrlField(value),
      );

  void setEpgUrl(String value) => state = state.copyWith(epgUrl: value);

  /// Validates then adds the playlist; the sync starts under the same gate
  /// and the returned future completes with its final progress (null when
  /// nothing was added). Refused while another sync runs.
  Future<SyncProgress?> submit() async {
    if (!state.canSubmit) {
      developer.log("m3u submit ignored: form invalid", name: "iptv.auth");
      return null;
    }
    final String epg = state.epgUrl.trim();
    return _add(
      () => ref.read(sourceRepositoryProvider).addM3uSource(
            name: state.effectiveName,
            url: state.url.trim(),
            epgUrl: epg.isEmpty ? null : epg,
          ),
    );
  }

  /// Seeds the bundled offline demo source (rich live + VOD + series) — no
  /// form, no network. Reuses [submission] so the connecting screen reports
  /// progress exactly like a normal add.
  Future<SyncProgress?> startDemo() =>
      _add(() => ref.read(sourceRepositoryProvider).addDemoSource());

  Future<SyncProgress?> _add(
    Future<Either<Failures, Source>> Function() add,
  ) async {
    state = state.copyWith(submission: const AsyncState<Source>.loading());
    final SyncGateOutcome<Source> outcome =
        await ref.read(sourceSyncProvider.notifier).changeSource<Source>(
      () async {
        final Either<Failures, Source> added = await add();
        if (added.isRight()) _followActiveSource();
        return added;
      },
    );
    switch (outcome) {
      case SyncGateRefused<Source>():
        state = state.copyWith(
          submission: const AsyncState<Source>.error(Failures.unexpected()),
        );
        return null;
      case SyncGateRan<Source>(
          :final Either<Failures, Source> result,
          :final Future<SyncProgress>? sync
        ):
        state = result.fold(
          (Failures failure) =>
              state.copyWith(submission: AsyncState<Source>.error(failure)),
          (Source source) =>
              state.copyWith(submission: AsyncState<Source>.success(source)),
        );
        return sync;
    }
  }

  /// The repository just switched the store to the new source: make the
  /// observable id and the Sources list follow it.
  void _followActiveSource() {
    ref.read(activeSourceIdProvider.notifier).sync();
    ref.invalidate(sourcesProvider);
  }
}
