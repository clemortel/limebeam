import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/source.dart";

part "xtream_form_state.freezed.dart";

/// Form state for the Xtream onboarding screen. All validation + submission
/// status live here (§7 — never in widget state).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class XtreamFormState with _$XtreamFormState {
  const XtreamFormState._();

  const factory XtreamFormState({
    @Default("") String name,
    @Default("") String host,
    @Default("") String username,
    @Default("") String password,
    String? nameError,
    String? hostError,
    String? usernameError,
    String? passwordError,
    @Default(AsyncState<Source>.idle()) AsyncState<Source> submission,
  }) = _XtreamFormState;

  /// True when every required field is filled and no field has an error.
  bool get canSubmit =>
      name.trim().isNotEmpty &&
      host.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      nameError == null &&
      hostError == null &&
      usernameError == null &&
      passwordError == null;
}
