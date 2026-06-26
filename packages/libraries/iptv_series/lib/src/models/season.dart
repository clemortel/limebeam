import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

import "episode.dart";

part "season.freezed.dart";

/// A season grouping its episodes.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Season with _$Season {
  const factory Season({
    required int number,
    required String name,
    required IList<Episode> episodes,
  }) = _Season;
}
