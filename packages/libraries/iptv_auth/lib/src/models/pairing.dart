import "package:freezed_annotation/freezed_annotation.dart";

part "pairing.freezed.dart";

/// Credentials a user typed on their phone during "type on your phone" pairing.
@freezed
sealed class PhoneCredentials with _$PhoneCredentials {
  const factory PhoneCredentials({
    required String name,
    required String host,
    required String username,
    required String password,
  }) = _PhoneCredentials;
}

/// UI state of an active pairing session. [url] is what the phone must open
/// (encoded in the QR). [phoneConnected] flips once a phone opens the page.
/// [received] holds the submitted credentials awaiting on-TV confirmation.
@freezed
sealed class PairingSession with _$PairingSession {
  const factory PairingSession({
    required String url,
    @Default(false) bool phoneConnected,
    PhoneCredentials? received,
  }) = _PairingSession;
}
