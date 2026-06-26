import "package:freezed_annotation/freezed_annotation.dart";

part "cast_device.freezed.dart";
part "cast_device.g.dart";

/// How a [CastDevice] receives the stream.
///
/// [chromecast] uses the Google Cast SDK (URL handoff on both platforms).
/// [airplay] is the iOS native route — picked through `AVRoutePickerView`,
/// so the system owns discovery and we never enumerate AirPlay devices here.
enum CastTransport { chromecast, airplay }

/// A discoverable TV / receiver the user can hand playback off to.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class CastDevice with _$CastDevice {
  const factory CastDevice({
    required String id,
    required String name,
    @Default(CastTransport.chromecast) CastTransport transport,
    @Default(false) bool isConnected,
  }) = _CastDevice;

  factory CastDevice.fromJson(Map<String, dynamic> json) =>
      _$CastDeviceFromJson(json);
}
