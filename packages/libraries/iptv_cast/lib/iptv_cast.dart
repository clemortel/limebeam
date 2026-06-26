/// iptv_cast — Cast to TV.
///
/// Chromecast handoff (both platforms) via the native Google Cast SDK, plus the
/// iOS AirPlay route (native `AVRoutePickerView`). The cast SDK types stay
/// hidden behind [ICastRepository]; the rest of the app depends on the domain
/// models ([CastDevice] / [CastSession]) and the Riverpod surface only.
///
/// Follows the 4-layer pattern — see `iptv_live` for the worked reference.
library iptv_cast;

export "src/di.dart";
export "src/infrastructure/cast_repository.dart" show ICastRepository;
export "src/models/cast_device.dart";
export "src/models/cast_session.dart";
export "src/riverpods/cast_devices_notifier.dart";
export "src/riverpods/providers.dart";
export "src/ui/airplay_route_picker.dart";
