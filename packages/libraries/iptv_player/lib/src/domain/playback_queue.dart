import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

import "playback_request.dart";

part "playback_queue.freezed.dart";

/// An ordered set of playable items + the starting index. Powers the player's
/// next/previous and the mini-list (channels in a category, episodes in a
/// season). A movie is a single-item queue.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class PlaybackQueue with _$PlaybackQueue {
  const PlaybackQueue._();

  const factory PlaybackQueue({
    required IList<PlaybackRequest> items,
    @Default(0) int index,
    @Default(false) bool autoplayNext,
    @Default(false) bool gesturesEnabled,
  }) = _PlaybackQueue;

  /// Convenience for content with no siblings (a movie).
  factory PlaybackQueue.single(
    PlaybackRequest request, {
    bool gesturesEnabled = false,
  }) =>
      PlaybackQueue(
        items: IList<PlaybackRequest>(<PlaybackRequest>[request]),
        gesturesEnabled: gesturesEnabled,
      );

  PlaybackRequest get current => items[index];

  /// True when the mini-list / prev-next controls are worth showing.
  bool get hasSiblings => items.length > 1;
}
