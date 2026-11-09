/// iptv_auth — portal credentials, multi-profile, parental PIN.
///
/// Public surface only. Implementation stays private under `src/`.
library;

export "src/di.dart";
export "src/infrastructure/source_repository.dart" show ISourceRepository;
export "src/models/connection_status.dart";
export "src/models/form_field_issue.dart";
export "src/models/portal_user_info.dart";
export "src/models/source.dart";
export "src/models/source_action_failure.dart";
export "src/models/source_link.dart";
export "src/models/source_type.dart";
export "src/riverpods/add_m3u_source_notifier.dart";
export "src/riverpods/add_xtream_source_notifier.dart";
export "src/riverpods/m3u_form_state.dart";
export "src/riverpods/providers.dart";
export "src/riverpods/source_link_notifier.dart";
export "src/riverpods/sources_notifier.dart";
export "src/riverpods/xtream_form_state.dart";
export "src/ui/m3u_form_view.dart";
export "src/ui/source_summary_view.dart";
export "src/ui/source_type_view.dart";
export "src/ui/sources_settings_view.dart";
export "src/ui/welcome_view.dart";
export "src/ui/xtream_form_view.dart";
