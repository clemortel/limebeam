import "package:freezed_annotation/freezed_annotation.dart";

part "epg_entry.freezed.dart";

/// A single EPG programme for one channel.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class EpgEntry with _$EpgEntry {
  const EpgEntry._();

  const factory EpgEntry({
    required String channelId,
    required DateTime start,
    required DateTime stop,
    required String title,
    @Default("") String description,
  }) = _EpgEntry;

  bool isLiveAt(DateTime at) => !at.isBefore(start) && at.isBefore(stop);

  /// Elapsed fraction 0..1 of this programme at [at].
  double progressAt(DateTime at) {
    final int total = stop.difference(start).inSeconds;
    if (total <= 0) return 0;
    final int elapsed = at.difference(start).inSeconds;
    return (elapsed / total).clamp(0, 1);
  }
}
