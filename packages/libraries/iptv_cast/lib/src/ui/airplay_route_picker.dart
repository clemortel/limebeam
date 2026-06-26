import "package:flutter/foundation.dart";
import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:iptv_ui/iptv_ui.dart";

/// Platform-view id for the native `AVRoutePickerView` registered in the iOS
/// Runner. Must match the factory id in `AirPlayRoutePickerFactory.swift`.
const String _kAirPlayViewType = "limebeam/airplay_route_picker";

/// Default tappable size of the native AirPlay button.
const double _kAirPlayPickerSize = 44;

/// Thin wrapper around the iOS native `AVRoutePickerView` (the system AirPlay
/// button). The system owns device discovery and routing; tapping presents the
/// native route sheet. Renders nothing off iOS.
///
/// NOTE: AirPlay only streams *video* when the audio/video is playing through
/// an `AVPlayer` route. media_kit (libmpv) does not follow the AirPlay route,
/// so true AirPlay video also requires the iOS AVPlayer playback engine — see
/// the engine contract in `iptv_player` (`playback_engine.dart`).
class AirPlayRoutePicker extends StatelessWidget {
  const AirPlayRoutePicker({this.size = _kAirPlayPickerSize, super.key});

  final double size;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width: size,
      height: size,
      child: const UiKitView(
        viewType: _kAirPlayViewType,
        creationParamsCodec: StandardMessageCodec(),
      ),
    );
  }
}

/// Sheet row exposing the AirPlay picker, styled to match the Chromecast device
/// rows. iOS-only; collapses to nothing elsewhere.
class AirPlayRouteTile extends StatelessWidget {
  const AirPlayRouteTile({super.key});

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final AppTheme t = context.appTheme;
    return Padding(
      padding:
          EdgeInsets.symmetric(horizontal: t.space.x4, vertical: t.space.x2),
      child: Row(
        children: <Widget>[
          Icon(Icons.airplay, color: t.colors.textPrimary),
          SizedBox(width: t.space.x4),
          Expanded(
            child: Text(
              "AirPlay",
              style: t.typography.body.copyWith(color: t.colors.textPrimary),
            ),
          ),
          const AirPlayRoutePicker(),
        ],
      ),
    );
  }
}
