import "dart:developer" as developer;

import "package:flutter/services.dart";
import "package:flutter_riverpod/misc.dart" show KeepAliveLink;
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/source_link.dart";
import "../models/source_type.dart";
import "add_m3u_source_notifier.dart";
import "add_xtream_source_notifier.dart";

part "source_link_notifier.g.dart";

/// Turns a pasted link into a pre-filled add flow. Stateless: the filled
/// state lives in the two add notifiers it seeds.
@riverpod
class SourceLinkNotifier extends _$SourceLinkNotifier {
  @override
  void build() {}

  /// Seeds the matching form from [raw]. Returns the detected type, or null
  /// when [raw] is not a usable link (the caller then shows the type picker).
  SourceType? apply(String raw) {
    final SourceLink? link = SourceLink.parse(raw);
    if (link == null) return null;
    switch (link) {
      case XtreamSourceLink(
          :final String host,
          :final String username,
          :final String password,
        ):
        ref.read(addXtreamSourceProvider.notifier)
          ..reset()
          ..applyLink(host: host, username: username, password: password);
        return SourceType.xtream;
      case M3uSourceLink(:final String url):
        ref.read(addM3uSourceProvider.notifier)
          ..reset()
          ..applyLink(url: url);
        return SourceType.m3u;
    }
  }

  /// Same as [apply] on the clipboard text; null when it holds no link or the
  /// clipboard cannot be read (denied, unavailable): the caller falls back to
  /// the manual flow.
  Future<SourceType?> applyClipboard() async {
    // Nothing listens to this auto-dispose notifier (it is only read), so it
    // would be disposed while the paste prompt is up and `ref` would throw.
    final KeepAliveLink link = ref.keepAlive();
    try {
      final ClipboardData? data = await Clipboard.getData(Clipboard.kTextPlain);
      final String? text = data?.text;
      if (text == null || !ref.mounted) return null;
      return apply(text);
    } on Exception catch (error, stackTrace) {
      developer.log(
        "clipboard unreadable: $error",
        name: "iptv.auth",
        stackTrace: stackTrace,
      );
      return null;
    } finally {
      link.close();
    }
  }
}
