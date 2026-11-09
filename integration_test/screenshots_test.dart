import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/bootstrap.dart";
import "package:green_iptv/flavors/flavor.dart";
import "package:integration_test/integration_test.dart";

const Duration _kSettle = Duration(seconds: 2);
const Duration _kDemoLoad = Duration(seconds: 15);

/// One screenshot per tab, each taken after a real tap on the tab label, so
/// no two store screenshots can be identical by construction. Tab labels
/// follow the current bar (Accueil, Direct, Films, Séries, Recherche); a
/// missing label skips the tap and the assert below then fails loudly.
const List<(String, String)> _kTabs = <(String, String)>[
  ("Direct", "03_live"),
  ("Films", "04_movies"),
  ("Séries", "05_series"),
  ("Recherche", "06_search"),
];

void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets("capture store screenshots", (WidgetTester tester) async {
    await bootstrap(Flavor.development);
    await _settle(tester, _kSettle);
    await binding.takeScreenshot("01_welcome");

    await _tap(tester, "Essayer la démo");
    await _settle(tester, _kDemoLoad);
    // The success screen moves on by itself; tap "Découvrir" only if the
    // capture caught it before the auto-advance.
    await _tapIfPresent(tester, "Découvrir");
    await _settle(tester, _kSettle);
    await binding.takeScreenshot("02_home");

    for (final (String label, String name) in _kTabs) {
      await _tap(tester, label);
      await _settle(tester, _kSettle);
      await binding.takeScreenshot(name);
    }
  });
}

Future<void> _settle(WidgetTester tester, Duration duration) async {
  final DateTime end = DateTime.now().add(duration);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 200));
  }
}

Future<void> _tapIfPresent(WidgetTester tester, String label) async {
  final Finder finder = find.text(label);
  if (finder.evaluate().isEmpty) return;
  await tester.tap(finder.first);
  await _settle(tester, const Duration(seconds: 1));
}

Future<void> _tap(WidgetTester tester, String label) async {
  final Finder finder = find.text(label);
  expect(finder, findsWidgets, reason: "no \"$label\" on screen");
  await tester.tap(finder.first);
  await _settle(tester, const Duration(seconds: 1));
}
