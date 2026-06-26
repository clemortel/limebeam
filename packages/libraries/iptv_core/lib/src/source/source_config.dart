import "package:freezed_annotation/freezed_annotation.dart";

part "source_config.freezed.dart";

/// Runtime connection config for a content provider. Shared by iptv_api
/// (the factory consumes it) and iptv_auth (persistence maps to it), so both
/// reference one type.
///
/// Run `melos run build_runner` after editing this union.
@freezed
sealed class SourceConfig with _$SourceConfig {
  const factory SourceConfig.xtream({
    required String host,
    required String username,
    required String password,
  }) = XtreamConfig;

  const factory SourceConfig.m3u({
    required String url,
    String? epgUrl,
  }) = M3uConfig;
}
