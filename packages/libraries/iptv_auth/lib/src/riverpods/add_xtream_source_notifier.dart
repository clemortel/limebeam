import "dart:developer" as developer;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/source.dart";
import "providers.dart";
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

  void setName(String value) => state = state.copyWith(
        name: value,
        nameError: value.trim().isEmpty ? "Nom requis" : null,
      );

  void setHost(String value) => state = state.copyWith(
        host: value,
        hostError: _validateHost(value),
      );

  void setUsername(String value) => state = state.copyWith(
        username: value,
        usernameError: value.trim().isEmpty ? "Nom d'utilisateur requis" : null,
      );

  void setPassword(String value) => state = state.copyWith(
        password: value,
        passwordError: value.isEmpty ? "Mot de passe requis" : null,
      );

  String? _validateHost(String value) {
    final String v = value.trim();
    if (v.isEmpty) return "URL requise";
    final Uri? uri = Uri.tryParse(v.contains("://") ? v : "http://$v");
    if (uri == null || uri.host.isEmpty) {
      return "URL invalide (ex. : http://monportail.tv:8080)";
    }
    return null;
  }

  /// Validates then connects. On success `state.submission` becomes
  /// `AsyncState.success(source)`; the screen listens and navigates.
  Future<void> submit() async {
    if (!state.canSubmit) {
      developer.log("submit ignored: form invalid", name: "iptv.auth");
      return;
    }
    developer.log("submit start", name: "iptv.auth");
    state = state.copyWith(submission: const AsyncState<Source>.loading());

    final Either<Failures, Source> result =
        await ref.read(sourceRepositoryProvider).addXtreamSource(
              name: state.name.trim(),
              host: state.host.trim(),
              username: state.username.trim(),
              password: state.password,
            );

    state = result.fold(
      (Failures failure) {
        developer.log("submit error → $failure", name: "iptv.auth");
        return state.copyWith(submission: AsyncState<Source>.error(failure));
      },
      (Source source) {
        developer.log("submit success id=${source.id}", name: "iptv.auth");
        return state.copyWith(submission: AsyncState<Source>.success(source));
      },
    );
  }
}
