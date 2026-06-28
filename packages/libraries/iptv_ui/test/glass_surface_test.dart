import "package:flutter/material.dart";
import "package:flutter_test/flutter_test.dart";
import "package:iptv_ui/iptv_ui.dart";

/// Hosts [child] inside a themed MaterialApp, optionally forcing the OS
/// high-contrast flag (which MaterialApp otherwise sources from the platform).
Widget _host(Widget child, {bool highContrast = false}) {
  return MaterialApp(
    theme: AppTheme.themeData(),
    home: Builder(
      builder: (BuildContext context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(highContrast: highContrast),
        child: Scaffold(body: Center(child: child)),
      ),
    ),
  );
}

void main() {
  group("GlassSurface accessibility fallback", () {
    testWidgets("renders glass (a backdrop blur) when enabled",
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const GlassSurface(enabled: true, child: Text("x"))),
      );

      expect(find.byType(BackdropFilter), findsOneWidget);
    });

    testWidgets("falls back to a solid surface when disabled",
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(const GlassSurface(enabled: false, child: Text("x"))),
      );

      // No backdrop blur; a solid decorated surface stands in instead.
      expect(find.byType(BackdropFilter), findsNothing);
      expect(find.byType(DecoratedBox), findsWidgets);
    });

    testWidgets("falls back to a solid surface under OS high contrast",
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const GlassSurface(enabled: true, child: Text("x")),
          highContrast: true,
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });

    testWidgets("defaults to the inherited GlassScope when no flag is given",
        (WidgetTester tester) async {
      await tester.pumpWidget(
        _host(
          const GlassScope(
            enabled: false,
            child: GlassSurface(child: Text("x")),
          ),
        ),
      );

      expect(find.byType(BackdropFilter), findsNothing);
    });
  });
}
