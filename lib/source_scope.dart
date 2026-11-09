import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_riverpod/flutter_riverpod.dart" show Ref;
import "package:flutter_riverpod/misc.dart" show Override, ProviderOrFamily;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_player/iptv_player.dart";
import "package:iptv_playlist/iptv_playlist.dart";

/// Per-source providers outside iptv_auth's reach (it must not depend on
/// iptv_favorites). Invalidated the moment the active source changes.
Override sourceScopedProvidersOverride() =>
    sourceScopedProvidersProvider.overrideWithValue(
      IList<ProviderOrFamily>(<ProviderOrFamily>[
        favoritesProvider,
        watchSessionsProvider,
      ]),
    );

/// Hooks the sync gate runs before the active source changes, wired here
/// because iptv_auth and iptv_playlist must not depend on iptv_player.
///
/// Playback is stopped while the old source is still active: the forced
/// progress save then lands in the old source's sessions, and its stream
/// (credentials in the URL) does not outlive the source.
Override beforeSourceSwitchHooksOverride() =>
    beforeSourceSwitchHooksProvider.overrideWithValue(
      IList<BeforeSourceSwitchHook>(<BeforeSourceSwitchHook>[
        (Ref ref) => ref.read(playbackControllerProvider.notifier).stop(),
      ]),
    );
