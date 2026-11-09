import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/misc.dart" show Override, ProviderOrFamily;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_favorites/iptv_favorites.dart";

/// Per-source providers outside iptv_auth's reach (it must not depend on
/// iptv_favorites). Invalidated the moment the active source changes.
Override sourceScopedProvidersOverride() =>
    sourceScopedProvidersProvider.overrideWithValue(
      IList<ProviderOrFamily>(<ProviderOrFamily>[
        favoritesProvider,
        watchSessionsProvider,
      ]),
    );
