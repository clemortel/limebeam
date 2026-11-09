import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/form_field_issue.dart";
import "../models/source.dart";
import "providers.dart";
import "sources_notifier.dart";
import "xtream_form_state.dart";

part "add_xtream_source_notifier.g.dart";

/// Drives the Xtream onboarding form: field validation + submission. The UI
/// pushes field changes here and reads validity/errors back. Kept alive so the
/// entered values survive the form → summary → connecting navigation.
@Riverpod(keepAlive: true)
class AddXtreamSourceNotifier extends _$AddXtreamSourceNotifier {
  @override
  XtreamFormState build() => const XtreamFormState();

  /// Clears the form when starting a fresh add flow.
  void reset() => state = const XtreamFormState();

  void setName(String value) => state = state.copyWith(name: value);

  /// Pre-fills the whole form from a pasted `get.php?username=…` link.
  void applyLink({
    required String host,
    required String username,
    required String password,
  }) {
    setHost(host);
    setUsername(username);
    setPassword(password);
  }

  void setHost(String value) => state = state.copyWith(
        host: value,
        hostError: validateUrlField(value),
      );

  void setUsername(String value) => state = state.copyWith(
        username: value,
        usernameError: value.trim().isEmpty ? FormFieldIssue.required : null,
      );

  void setPassword(String value) => state = state.copyWith(
        password: value,
        passwordError: value.isEmpty ? FormFieldIssue.required : null,
      );

  /// The connecting screen's Retry. When the source was already added and
  /// only the sync failed, re-runs the sync alone: adding again would leave
  /// one more copy in Settings > Sources per retry (each add gets a new id).
  /// Re-submits only when the add itself did not succeed.
  Future<SyncProgress?> retry() {
    if (state.submission is AsyncSuccess<Source>) {
      return ref.read(sourceSyncProvider.notifier).run();
    }
    return submit();
  }

  /// Validates then connects. On success `state.submission` becomes
  /// `AsyncState.success(source)` and the sync starts under the same gate;
  /// the returned future completes with its final progress (null when
  /// nothing was added). Refused while another sync runs.
  Future<SyncProgress?> submit() async {
    if (!state.canSubmit) {
      developer.log("submit ignored: form invalid", name: "iptv.auth");
      return null;
    }
    developer.log("submit start", name: "iptv.auth");
    state = state.copyWith(
      submission: const AsyncState<Source>.loading(),
      syncBusy: false,
    );

    final SyncGateOutcome<Source> outcome =
        await ref.read(sourceSyncProvider.notifier).changeSource<Source>(
      () async {
        final Either<Failures, SourceSwitchCommit<Source>> prepared =
            await ref.read(sourceRepositoryProvider).prepareXtreamSource(
                  name: state.effectiveName,
                  host: state.host.trim(),
                  username: state.username.trim(),
                  password: state.password,
                );
        return prepared.map(
          (SourceSwitchCommit<Source> commit) => () async {
            final Either<Failures, Source> added = await commit();
            if (added.isRight()) _followActiveSource();
            return added;
          },
        );
      },
    );

    switch (outcome) {
      case SyncGateRefused<Source>():
        developer.log("submit refused: sync in flight", name: "iptv.auth");
        state = state.copyWith(
          submission: const AsyncState<Source>.idle(),
          syncBusy: true,
        );
        return null;
      case SyncGateRan<Source>(
          :final Either<Failures, Source> result,
          :final Future<SyncProgress>? sync
        ):
        state = result.fold(
          (Failures failure) {
            developer.log("submit error → $failure", name: "iptv.auth");
            return state.copyWith(
              submission: AsyncState<Source>.error(failure),
            );
          },
          (Source source) {
            developer.log("submit success id=${source.id}", name: "iptv.auth");
            return state.copyWith(
              submission: AsyncState<Source>.success(source),
            );
          },
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
