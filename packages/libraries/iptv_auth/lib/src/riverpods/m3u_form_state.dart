import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/form_field_issue.dart";
import "../models/source.dart";

part "m3u_form_state.freezed.dart";

/// Form state for the M3U onboarding screen. Validation + submission status
/// live here (§7 — never in widget state).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class M3uFormState with _$M3uFormState {
  const M3uFormState._();

  const factory M3uFormState({
    @Default("") String name,
    @Default("") String url,
    @Default("") String epgUrl,
    FormFieldIssue? nameError,
    FormFieldIssue? urlError,
    @Default(AsyncState<Source>.idle()) AsyncState<Source> submission,
  }) = _M3uFormState;

  /// The name is optional: a blank one falls back to the playlist host.
  String get effectiveName {
    final String typed = name.trim();
    if (typed.isNotEmpty) return typed;
    final String u = url.trim();
    return Uri.tryParse(u.contains("://") ? u : "http://$u")?.host ?? u;
  }

  /// True when the URL is filled and valid (name and EPG URL are optional).
  bool get canSubmit =>
      url.trim().isNotEmpty &&
      urlError == null;
}
