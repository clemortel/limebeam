import "package:freezed_annotation/freezed_annotation.dart";

part "channel.freezed.dart";
part "channel.g.dart";

/// A live TV channel. Immutable; lists of channels use IList in state and
/// signatures (see riverpods/).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Channel with _$Channel {
  const Channel._();

  const factory Channel({
    required String id,
    required String name,
    required String streamId,
    required String categoryId,
    String? logoUrl,
    String? epgChannelId,
    @Default(0) int number,
  }) = _Channel;

  factory Channel.fromJson(Map<String, dynamic> json) =>
      _$ChannelFromJson(json);

  /// Model constant instead of a magic number at the call site.
  static const int maxRetryCount = 3;
}
