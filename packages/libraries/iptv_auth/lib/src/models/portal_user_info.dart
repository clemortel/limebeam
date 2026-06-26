import "package:freezed_annotation/freezed_annotation.dart";

part "portal_user_info.freezed.dart";

/// Account info returned by the Xtream `user_info` block on authenticate.
@freezed
sealed class PortalUserInfo with _$PortalUserInfo {
  const PortalUserInfo._();

  const factory PortalUserInfo({
    required String status,
    int? expiryEpoch,
    int? maxConnections,
    int? activeConnections,
  }) = _PortalUserInfo;

  /// Parses the Xtream `user_info` map defensively (fields are often strings).
  factory PortalUserInfo.fromUserInfo(Map<String, dynamic> userInfo) {
    int? toInt(dynamic v) => switch (v) {
          final int i => i,
          final String s => int.tryParse(s),
          _ => null,
        };
    return PortalUserInfo(
      status: "${userInfo["status"] ?? "Unknown"}",
      expiryEpoch: toInt(userInfo["exp_date"]),
      maxConnections: toInt(userInfo["max_connections"]),
      activeConnections: toInt(userInfo["active_cons"]),
    );
  }

  DateTime? get expiryDate => expiryEpoch == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(expiryEpoch! * 1000);
}
