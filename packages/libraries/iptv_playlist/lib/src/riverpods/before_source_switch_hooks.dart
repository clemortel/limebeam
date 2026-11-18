import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "before_source_switch_hooks.g.dart";

/// Work to finish while the outgoing source is still the active one.
typedef BeforeSourceSwitchHook = Future<void> Function(Ref ref);

/// Hooks run by the sync gate right before every active-source change
/// (activate, delete of the active source, add), in order.
///
/// Trap: they must run before the store switches. Stopping playback saves
/// its progress through the active source, so running it after the switch
/// would file source A's progress under source B. The app root overrides
/// this with what iptv_playlist cannot depend on (the player).
@Riverpod(keepAlive: true)
IList<BeforeSourceSwitchHook> beforeSourceSwitchHooks(Ref ref) =>
    IList<BeforeSourceSwitchHook>();
