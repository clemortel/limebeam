import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/bootstrap.dart";
import "package:green_iptv/flavors/flavor.dart";
import "package:integration_test/integration_test.dart";

/// Captures App Store / Play Store marketing screenshots by driving the real
/// app through the credential-free demo flow. Run once per device size you want
/// (e.g. an iPhone 6.7" simulator, an iPhone 6.5" simulator, an Android phone
/// emulator) — see `test_driver/integration_test.dart` for the command.
///
/// Steps are resilient: a missing widget or a slow network sync is swallowed so
/// an earlier shot is never lost. Selectors are by visible label — adjust here
/// if UI copy changes.
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("capture store screenshots", (WidgetTester tester) async {
    await bootstrap(Flavor.development);
    await _settle(tester, const Duration(seconds: 2));
    await _shoot(binding, tester, "01_welcome");

    // Demo mode = populated app without any credentials.
    await _tapLabel(tester, "Essayer la démo");
    await _settle(tester, const Duration(seconds: 15)); // demo source sync
    await _shoot(binding, tester, "02_home");

    await _tapLabel(tester, "Films & Séries");
    await _settle(tester, const Duration(seconds: 3));
    await _shoot(binding, tester, "03_browse");

    await _tapLabel(tester, "Réglages");
    await _settle(tester, const Duration(seconds: 2));
    await _shoot(binding, tester, "04_settings");

    await _tapLabel(tester, "Soutenir le développeur");
    await _settle(tester, const Duration(seconds: 3));
    await _shoot(binding, tester, "05_tip_jar");
  });
}

/// Pumps for [duration] without throwing on lingering animations / network
/// (unlike `pumpAndSettle`, which times out on an endless frame source).
Future<void> _settle(WidgetTester tester, Duration duration) async {
  final DateTime end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

/// Taps the first widget showing [label]; no-op if it is absent on this screen.
Future<void> _tapLabel(WidgetTester tester, String label) async {
  final Finder finder = find.text(label);
  if (finder.evaluate().isEmpty) return;
  await tester.tap(finder.first);
  await _settle(tester, const Duration(seconds: 1));
}

/// Android needs the surface converted to an image before a screenshot.
Future<void> _shoot(
  IntegrationTestWidgetsFlutterBinding binding,
  WidgetTester tester,
  String name,
) async {
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    await binding.convertFlutterSurfaceToImage();
    await tester.pump();
  }
  await binding.takeScreenshot(name);
}
