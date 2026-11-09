import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/form_field_issue.dart";
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
    FormFieldIssue? hostError,
    FormFieldIssue? usernameError,
    FormFieldIssue? passwordError,
    @Default(AsyncState<Source>.idle()) AsyncState<Source> submission,
  }) = _XtreamFormState;

  /// The name is optional: a blank one falls back to the portal host.
  String get effectiveName {
    final String typed = name.trim();
    if (typed.isNotEmpty) return typed;
    final String h = host.trim();
    return Uri.tryParse(h.contains("://") ? h : "http://$h")?.host ?? h;
  }

  /// True when every required field is filled and no field has an error.
  bool get canSubmit =>
      host.trim().isNotEmpty &&
      username.trim().isNotEmpty &&
      password.isNotEmpty &&
      hostError == null &&
      usernameError == null &&
      passwordError == null;
}
