import "package:freezed_annotation/freezed_annotation.dart";
import "package:iptv_core/iptv_core.dart";

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
    String? nameError,
    String? urlError,
    @Default(AsyncState<Source>.idle()) AsyncState<Source> submission,
  }) = _M3uFormState;

  /// True when name + URL are filled and valid (EPG URL is optional).
  bool get canSubmit =>
      name.trim().isNotEmpty &&
      url.trim().isNotEmpty &&
      nameError == null &&
      urlError == null;
}
