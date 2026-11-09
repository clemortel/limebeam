import "dart:async";

import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";

const String _kLink = "http://example.com/list.m3u";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  void mockClipboard(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, handler);
  }

  test("should survive disposal while the clipboard prompt is pending",
      () async {
    final Completer<void> prompt = Completer<void>();
    mockClipboard((MethodCall call) async {
      await prompt.future;
      return <String, Object?>{"text": _kLink};
    });

    // Only read, never listened to: exactly how the screens reach it.
    final Future<SourceType?> pending =
        container.read(sourceLinkProvider.notifier).applyClipboard();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    prompt.complete();

    expect(await pending, SourceType.m3u);
    expect(container.read(addM3uSourceProvider).url, _kLink);
  });

  test("should return null when the clipboard cannot be read", () async {
    mockClipboard((MethodCall call) async {
      throw PlatformException(code: "denied");
    });

    final SourceType? type =
        await container.read(sourceLinkProvider.notifier).applyClipboard();

    expect(type, isNull);
  });

  test("should return null when the clipboard holds no link", () async {
    mockClipboard(
      (MethodCall call) async => <String, Object?>{"text": "hello"},
    );

    final SourceType? type =
        await container.read(sourceLinkProvider.notifier).applyClipboard();

    expect(type, isNull);
  });
}
