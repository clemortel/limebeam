import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";
import "package:xml/xml.dart";

import "../models/epg_entry.dart";

/// EPG data layer: fetch XMLTV, cache it, parse off-isolate, expose now/next.
abstract interface class IEpgRepository {
  Future<Either<Failures, int>> sync();

  /// All parsed entries from cache (may be empty when no EPG is available).
  Future<Either<Failures, IList<EpgEntry>>> getAll();
}

@LazySingleton(as: IEpgRepository)
class EpgRepository implements IEpgRepository {
  EpgRepository(this._factory, this._activeStore, this._cache);

  final PlaylistSourceFactory _factory;
  final ActiveSourceStore _activeStore;
  final CacheStore _cache;

  String get _key => "epg_${_activeStore.sourceId ?? "none"}";

  @override
  Future<Either<Failures, int>> sync() async {
    try {
      final SourceConfig? config = _activeStore.config;
      if (config == null) return left(const Failures.unexpected());

      final Either<Failures, String> result =
          await _factory.create(config).fetchEpg();

      return await result.fold(
        (Failures failure) async => left(const Failures.epgUnavailable()),
        (String xml) async {
          await _cache.write(_key, xml);
          return right(xml.length);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<EpgEntry>>> getAll() async {
    try {
      final String? raw = _cache.read(_key);
      if (raw == null || raw.isEmpty) {
        return right(const IListConst<EpgEntry>(<EpgEntry>[]));
      }
      final List<EpgEntry> entries = await runParse(parseXmltv, raw);
      return right(entries.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

// --- Top-level XMLTV parser (run via compute) ------------------------------

List<EpgEntry> parseXmltv(String xml) {
  final XmlDocument doc = XmlDocument.parse(xml);
  final List<EpgEntry> entries = <EpgEntry>[];
  for (final XmlElement p in doc.findAllElements("programme")) {
    final DateTime? start = _parseXmltvTime(p.getAttribute("start"));
    final DateTime? stop = _parseXmltvTime(p.getAttribute("stop"));
    final String channel = p.getAttribute("channel") ?? "";
    if (start == null || stop == null || channel.isEmpty) continue;
    entries.add(
      EpgEntry(
        channelId: channel,
        start: start,
        stop: stop,
        title: _firstText(p, "title"),
        description: _firstText(p, "desc"),
      ),
    );
  }
  return entries;
}

String _firstText(XmlElement parent, String tag) {
  final Iterable<XmlElement> els = parent.findElements(tag);
  return els.isEmpty ? "" : els.first.innerText.trim();
}

/// Parses XMLTV time like "20240615200000 +0000" into UTC DateTime.
DateTime? _parseXmltvTime(String? value) {
  if (value == null || value.length < 14) return null;
  final String digits = value.substring(0, 14);
  final int? y = int.tryParse(digits.substring(0, 4));
  final int? mo = int.tryParse(digits.substring(4, 6));
  final int? d = int.tryParse(digits.substring(6, 8));
  final int? h = int.tryParse(digits.substring(8, 10));
  final int? mi = int.tryParse(digits.substring(10, 12));
  final int? s = int.tryParse(digits.substring(12, 14));
  if (y == null || mo == null || d == null) return null;
  return DateTime.utc(y, mo, d, h ?? 0, mi ?? 0, s ?? 0);
}
