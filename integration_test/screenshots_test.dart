import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/bootstrap.dart";
import "package:green_iptv/flavors/flavor.dart";
import "package:integration_test/integration_test.dart";
void main() {
  final IntegrationTestWidgetsFlutterBinding binding =
      IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets("capture store screenshots", (WidgetTester tester) async {
    await bootstrap(Flavor.development);
    await _s(tester, const Duration(seconds: 2));
    await _t(tester, "Essayer la démo");
    await _s(tester, const Duration(seconds: 15));
    await _t(tester, "Découvrir");
    await _s(tester, const Duration(seconds: 3));
    await _t(tester, "Films & Séries");
    await _s(tester, const Duration(seconds: 3));
    await binding.takeScreenshot("nav_browse");
  });
}
Future<void> _s(WidgetTester t, Duration d) async {
  final DateTime e = DateTime.now().add(d);
  while (DateTime.now().isBefore(e)) { await t.pump(const Duration(milliseconds: 200)); }
}
Future<void> _t(WidgetTester te, String l) async {
  final Finder f = find.text(l); if (f.evaluate().isEmpty) return;
  await te.tap(f.first); await _s(te, const Duration(seconds: 1));
}
