import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/channel.dart";
import "providers.dart";

part "live_channels_notifier.g.dart";

/// Loads live channels from cache and exposes them as the custom [AsyncState].
/// Long-lived cache → keepAlive + silent refresh to avoid UI flicker.
@Riverpod(keepAlive: true)
class LiveChannelsNotifier extends _$LiveChannelsNotifier {
  @override
  AsyncState<IList<Channel>> build() {
    _fetch();
    return const AsyncState<IList<Channel>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<Channel>> result =
        await ref.read(liveRepositoryProvider).getChannels();
    state = result.fold(
      (Failures failure) => AsyncState<IList<Channel>>.error(failure),
      (IList<Channel> channels) =>
          AsyncState<IList<Channel>>.success(channels),
    );
  }

  /// Re-fetches from the network then reloads from cache.
  Future<void> refresh() async {
    state = const AsyncState<IList<Channel>>.loading();
    await ref.read(liveRepositoryProvider).sync();
    await _fetch();
  }

  /// Reloads from cache without showing a loading flash (post-sync).
  Future<void> silentRefresh() => _fetch();
}
