import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:flutter_test/flutter_test.dart";
import "package:iptv_auth/iptv_auth.dart";

void main() {
  late ProviderContainer container;

  setUp(() {
    container = ProviderContainer();
    addTearDown(container.dispose);
  });

  group("Xtream form", () {
    test("can submit without a name and falls back to the host", () {
      container.read(addXtreamSourceProvider.notifier)
        ..setHost("http://portal.tv:8080")
        ..setUsername("u")
        ..setPassword("p");

      final XtreamFormState state = container.read(addXtreamSourceProvider);

      expect(state.canSubmit, isTrue);
      expect(state.effectiveName, "portal.tv");
    });

    test("keeps a typed name", () {
      container.read(addXtreamSourceProvider.notifier)
        ..setName("  Salon ")
        ..setHost("portal.tv");

      expect(container.read(addXtreamSourceProvider).effectiveName, "Salon");
    });

    test("reports issues as codes, never as copy", () {
      container.read(addXtreamSourceProvider.notifier)
        ..setHost("")
        ..setUsername(" ")
        ..setPassword("");

      final XtreamFormState state = container.read(addXtreamSourceProvider);

      expect(state.hostError, FormFieldIssue.required);
      expect(state.usernameError, FormFieldIssue.required);
      expect(state.passwordError, FormFieldIssue.required);
      expect(state.canSubmit, isFalse);
    });
  });

  group("M3U form", () {
    test("can submit with only a URL and names itself after the host", () {
      container
          .read(addM3uSourceProvider.notifier)
          .setUrl("http://example.com/list.m3u");

      final M3uFormState state = container.read(addM3uSourceProvider);

      expect(state.canSubmit, isTrue);
      expect(state.effectiveName, "example.com");
    });

    test("flags an address without a host", () {
      container.read(addM3uSourceProvider.notifier).setUrl("http://");

      expect(
        container.read(addM3uSourceProvider).urlError,
        FormFieldIssue.invalidUrl,
      );
    });
  });

  group("SourceLinkNotifier", () {
    test("an Xtream link fills the Xtream form and ends ready to submit", () {
      final SourceType? type = container
          .read(sourceLinkProvider.notifier)
          .apply("http://p.tv:8080/get.php?username=u&password=p&type=m3u");

      expect(type, SourceType.xtream);
      final XtreamFormState form = container.read(addXtreamSourceProvider);
      expect(form.host, "http://p.tv:8080");
      expect(form.username, "u");
      expect(form.password, "p");
      expect(form.canSubmit, isTrue);
    });

    test("a playlist link fills the M3U form", () {
      final SourceType? type = container
          .read(sourceLinkProvider.notifier)
          .apply("https://example.com/list.m3u8");

      expect(type, SourceType.m3u);
      expect(
        container.read(addM3uSourceProvider).url,
        "https://example.com/list.m3u8",
      );
    });

    test("anything else is refused and touches nothing", () {
      final SourceType? type =
          container.read(sourceLinkProvider.notifier).apply("not a link");

      expect(type, isNull);
      expect(container.read(addM3uSourceProvider).url, isEmpty);
    });
  });
}
