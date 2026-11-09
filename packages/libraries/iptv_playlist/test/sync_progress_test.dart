import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_playlist/iptv_playlist.dart";

void main() {
  test("stepNumber counts the visible steps and ends on the total", () {
    int n(SyncStep step) => SyncProgress(step: step).stepNumber;

    expect(n(SyncStep.connecting), 0);
    expect(n(SyncStep.live), 1);
    expect(n(SyncStep.epg), 4);
    expect(n(SyncStep.done), kSyncStepCount);
    expect(n(SyncStep.failed), 0);
  });

  testWidgets("success summary auto-advances after its delay, once",
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    final List<bool> seen = <bool>[];
    container.listen<bool>(
      successAutoAdvanceProvider,
      (bool? _, bool next) => seen.add(next),
    );

    await tester
        .pump(kSuccessAutoAdvanceDelay - const Duration(milliseconds: 1));
    expect(seen, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(seen, <bool>[true]);
  });

  testWidgets("leaving the success screen cancels the timer",
      (WidgetTester tester) async {
    final ProviderContainer container = ProviderContainer();
    container
        .listen<bool>(successAutoAdvanceProvider, (bool? _, bool __) {})
        .close();
    container.dispose();

    // A pending timer would fail the test at teardown.
    await tester.pump(kSuccessAutoAdvanceDelay);
  });
}
