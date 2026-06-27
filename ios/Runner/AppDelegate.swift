import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    let registry = engineBridge.pluginRegistry
    GeneratedPluginRegistrant.register(with: registry)
    // Native AirPlay route picker (AVRoutePickerView), embedded via UiKitView.
    if let registrar = registry.registrar(forPlugin: "AirPlayRoutePicker") {
      registrar.register(
        AirPlayRoutePickerFactory(),
        withId: "limebeam/airplay_route_picker")
    }
    // Native AVPlayer engine (iOS playback + AirPlay video).
    if let registrar = registry.registrar(forPlugin: "AVPlayerEngine") {
      AVPlayerEngineController.register(with: registrar)
    }
    // Output-route monitor: tells Dart when AirPlay is active so playback can
    // swap to the AVPlayer engine (libmpv otherwise, for codec coverage).
    if let registrar = registry.registrar(forPlugin: "AirPlayRouteMonitor") {
      AirPlayRouteMonitor.register(with: registrar)
    }
  }
}
