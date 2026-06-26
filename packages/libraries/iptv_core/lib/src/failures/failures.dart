import "package:freezed_annotation/freezed_annotation.dart";

part "failures.freezed.dart";

/// Domain-level error union shared across all repositories.
///
/// Network variants come first, IPTV-specific variants follow. Repositories
/// return `Future<Either<Failures, T>>` and never leak raw exceptions.
///
/// Run `melos run build_runner` after editing this union.
@freezed
sealed class Failures with _$Failures {
  // Network / transport.
  const factory Failures.network() = NetworkError;
  const factory Failures.server(int code) = ServerError;
  const factory Failures.notFound() = NotFound;
  const factory Failures.unexpected() = Unexpected;

  // IPTV-specific.
  const factory Failures.invalidPlaylist() = InvalidPlaylist; // bad M3U/Xtream
  const factory Failures.portalAuth() = PortalAuthFailure; // wrong/expired creds
  const factory Failures.streamUnavailable() = StreamUnavailable;
  const factory Failures.epgUnavailable() = EpgUnavailable;

  // Casting (Chromecast / AirPlay handoff).
  const factory Failures.castUnavailable() = CastUnavailable; // no SDK/devices
  const factory Failures.castConnectionFailed() = CastConnectionFailed;
}
