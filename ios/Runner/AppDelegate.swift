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
  }
}
