import "package:flutter/widgets.dart" show Locale;
import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/bootstrap.dart";
import "package:green_iptv/flavors/flavor.dart";
import "package:integration_test/integration_test.dart";
import "package:iptv_l10n/iptv_l10n.dart";

const Duration _kSettle = Duration(seconds: 2);
const Duration _kDemoLoad = Duration(seconds: 15);

/// Locale of the store screenshots; tab labels are looked up in its
/// localizations, so renaming a tab in the ARB files never breaks the script.
const Locale _kLocale = Locale("fr");

/// One screenshot per tab, each taken after a real tap on the tab label, so
/// no two store screenshots can be identical by construction. A label that is
/// not on screen fails the run at once (see [_tap]); it does not skip.
final List<(String Function(AppLocalizations), String)> _kTabs =
    <(String Function(AppLocalizations), String)>[
  ((AppLocalizations l) => l.tabTv, "03_live"),
  ((AppLocalizations l) => l.browseMovies, "04_movies"),
  ((AppLocalizations l) => l.browseSeries, "05_series"),
  ((AppLocalizations l) => l.tabSearch, "06_search"),
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

    final AppLocalizations l10n = lookupAppLocalizations(_kLocale);
    for (final (String Function(AppLocalizations) label, String name)
        in _kTabs) {
      await _tap(tester, label(l10n));
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
