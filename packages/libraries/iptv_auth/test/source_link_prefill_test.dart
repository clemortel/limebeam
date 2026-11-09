import "package:flutter/services.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";
import "package:riverpod/src/framework.dart" show Override;

import "source_link_prefill_test.mocks.dart";

const String _kXtreamLink =
    "http://p.tv:8080/get.php?username=u&password=p&type=m3u_plus";
const String _kM3uLink = "https://example.com/list.m3u8";

// Run `melos run build_runner` to generate the mocks.
@GenerateMocks(<Type>[ISourceRepository])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockISourceRepository repository;
  late ProviderContainer container;

  setUp(() {
    repository = MockISourceRepository();
    container = ProviderContainer(
      overrides: <Override>[
        sourceRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
  });

  void clipboardHolds(String text) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      SystemChannels.platform,
      (MethodCall call) async => <String, Object?>{"text": text},
    );
  }

  test("should pre-fill the Xtream form and not submit it", () async {
    clipboardHolds(_kXtreamLink);

    final SourceType? type =
        await container.read(sourceLinkProvider.notifier).applyClipboard();

    expect(type, SourceType.xtream);
    final XtreamFormState form = container.read(addXtreamSourceProvider);
    expect(form.host, "http://p.tv:8080");
    expect(form.username, "u");
    expect(form.password, "p");
    expect(form.name, isEmpty);
    expect(form.submission, const AsyncState<Source>.idle());
    verifyZeroInteractions(repository);
  });

  test("should pre-fill the M3U form and not submit it", () async {
    clipboardHolds(_kM3uLink);

    final SourceType? type =
        await container.read(sourceLinkProvider.notifier).applyClipboard();

    expect(type, SourceType.m3u);
    final M3uFormState form = container.read(addM3uSourceProvider);
    expect(form.url, _kM3uLink);
    expect(form.name, isEmpty);
    expect(form.submission, const AsyncState<Source>.idle());
    verifyZeroInteractions(repository);
  });

  test("should fall back to the manual flow on a non-URL clipboard", () async {
    clipboardHolds("buy milk");

    final SourceType? type =
        await container.read(sourceLinkProvider.notifier).applyClipboard();

    expect(type, isNull);
    expect(container.read(addM3uSourceProvider).url, isEmpty);
    expect(container.read(addXtreamSourceProvider).host, isEmpty);
    verifyZeroInteractions(repository);
  });
}
