/// iptv_favorites — Favorites + continue-watching / resume positions.
///
/// Public surface only. Implementation stays private under `src/`.
library;

export "src/di.dart";
export "src/infrastructure/favorites_repository.dart" show IFavoritesRepository;
export "src/models/content_kind.dart";
export "src/models/favorite.dart";
export "src/models/watch_session.dart";
export "src/riverpods/favorites_notifier.dart";
export "src/riverpods/providers.dart";
export "src/riverpods/watch_sessions_notifier.dart";
