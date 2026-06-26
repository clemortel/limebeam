import "package:freezed_annotation/freezed_annotation.dart";

import "connection_status.dart";
import "source_type.dart";

part "source.freezed.dart";
part "source.g.dart";

/// Non-secret metadata for a saved source. Credentials never live here — they
/// are stored separately in secure storage (see [SourceRepository]).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class Source with _$Source {
  const factory Source({
    required String id,
    required String name,
    required SourceType type,
    required int createdAtEpochMs,
    @Default(ConnectionStatus.unknown) ConnectionStatus status,
  }) = _Source;

  factory Source.fromJson(Map<String, dynamic> json) => _$SourceFromJson(json);
}
