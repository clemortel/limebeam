import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/source.dart";
import "m3u_form_state.dart";
import "providers.dart";

part "add_m3u_source_notifier.g.dart";

/// Drives the M3U onboarding form: validation + submission. Kept alive so the
/// values survive form → connecting navigation.
@Riverpod(keepAlive: true)
class AddM3uSourceNotifier extends _$AddM3uSourceNotifier {
  @override
  M3uFormState build() => const M3uFormState();

  void reset() => state = const M3uFormState();

  void setName(String value) => state = state.copyWith(
        name: value,
        nameError: value.trim().isEmpty ? "Nom requis" : null,
      );

  void setUrl(String value) => state = state.copyWith(
        url: value,
        urlError: _validateUrl(value),
      );

  void setEpgUrl(String value) => state = state.copyWith(epgUrl: value);

  String? _validateUrl(String value) {
    final String v = value.trim();
    if (v.isEmpty) return "URL requise";
    final Uri? uri = Uri.tryParse(v.contains("://") ? v : "http://$v");
    if (uri == null || uri.host.isEmpty) {
      return "URL invalide (ex. : http://exemple.com/playlist.m3u)";
    }
    return null;
  }

  Future<void> submit() async {
    if (!state.canSubmit) {
      developer.log("m3u submit ignored: form invalid", name: "iptv.auth");
      return;
    }
    state = state.copyWith(submission: const AsyncState<Source>.loading());

    final String epg = state.epgUrl.trim();
    final Either<Failures, Source> result =
        await ref.read(sourceRepositoryProvider).addM3uSource(
              name: state.name.trim(),
              url: state.url.trim(),
              epgUrl: epg.isEmpty ? null : epg,
            );

    state = result.fold(
      (Failures failure) =>
          state.copyWith(submission: AsyncState<Source>.error(failure)),
      (Source source) =>
          state.copyWith(submission: AsyncState<Source>.success(source)),
    );
  }

  /// Seeds the bundled offline demo source (rich live + VOD + series) — no
  /// form, no network. Reuses [submission] so the connecting screen reports
  /// progress exactly like a normal add.
  Future<void> startDemo() async {
    state = state.copyWith(submission: const AsyncState<Source>.loading());

    final Either<Failures, Source> result =
        await ref.read(sourceRepositoryProvider).addDemoSource();

    state = result.fold(
      (Failures failure) =>
          state.copyWith(submission: AsyncState<Source>.error(failure)),
      (Source source) =>
          state.copyWith(submission: AsyncState<Source>.success(source)),
    );
  }
}
