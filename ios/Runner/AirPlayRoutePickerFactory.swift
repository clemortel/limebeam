import AVKit
import Flutter
import UIKit

/// Registers a native `AVRoutePickerView` (the system AirPlay button) as a
/// Flutter platform view. The Dart side embeds it via `UiKitView` with the
/// matching view type id `limebeam/airplay_route_picker`.
///
/// The picker presents the system route sheet; iOS owns AirPlay discovery and
/// routing. Note that audio/video only follows the chosen route when playback
/// runs through an `AVPlayer`/`AVAudioSession` — see the AVPlayer engine work
/// in `iptv_player`.
class AirPlayRoutePickerFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect,
    viewIdentifier viewId: Int64,
    arguments args: Any?
  ) -> FlutterPlatformView {
    return AirPlayRoutePickerView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

class AirPlayRoutePickerView: NSObject, FlutterPlatformView {
  private let routePicker: AVRoutePickerView

  init(frame: CGRect) {
    routePicker = AVRoutePickerView(frame: frame)
    routePicker.prioritizesVideoDevices = true
    // Lime accent for the active state; white otherwise (matches the dark UI).
    routePicker.activeTintColor = UIColor(
      red: 0xC5 / 255.0, green: 0xF0 / 255.0, blue: 0x3A / 255.0, alpha: 1.0)
    routePicker.tintColor = UIColor(
      red: 0xF4 / 255.0, green: 0xF6 / 255.0, blue: 0xF8 / 255.0, alpha: 1.0)
    super.init()
  }

  func view() -> UIView {
    return routePicker
  }
}
