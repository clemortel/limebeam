/// iptv_epg — XMLTV EPG fetch, cache, now/next lookup.
///
/// Public surface only. Implementation stays private under `src/`.
library;

export "src/di.dart";
export "src/infrastructure/epg_repository.dart" show IEpgRepository;
export "src/models/epg_entry.dart";
export "src/riverpods/providers.dart";
