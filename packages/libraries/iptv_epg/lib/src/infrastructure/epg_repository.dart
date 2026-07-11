import "dart:convert";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:injectable/injectable.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_core/iptv_core.dart";
import "package:xml/xml_events.dart";

import "../models/epg_entry.dart";

/// How far back / forward programmes are kept when the XMLTV feed is pruned
/// at sync time. Providers ship multi-day feeds (observed: 64MB of raw XML);
/// the guide only ever shows around "now", so everything outside the window
/// is dead weight that bloats the cache and the parse.
const Duration _kEpgPastWindow = Duration(hours: 12);
const Duration _kEpgFutureWindow = Duration(hours: 48);

/// Cap for programme descriptions kept in the cache — the guide shows a
/// short synopsis, not an essay, and descriptions dominate feed size.
const int _kEpgDescriptionMaxChars = 300;

/// EPG data layer: fetch XMLTV, prune + compact it off-isolate at sync time,
/// cache the compact JSON, expose now/next.
///
/// The raw XMLTV is deliberately NOT cached: a single 64MB XML value made the
/// Hive box scan take seconds at startup, blocked the UI thread for ~7s per
/// read (browsing ANR), and OOM'd the app on low-RAM TV devices.
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

  String get _sid => _activeStore.sourceId ?? "none";

  /// v2: compact JSON rows. The v1 key held raw XMLTV (see class doc).
  String get _key => "epg2_$_sid";
  String get _legacyKey => "epg_$_sid";

  /// One automatic re-sync per session when the compact cache is missing —
  /// covers devices upgrading from the raw-XML cache without forcing the
  /// user back through the connect flow.
  bool _resyncAttempted = false;

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
          final String encoded = await runParse(parseXmltvToJson, xml);
          await _cache.write(_key, encoded);
          // Reclaim the v1 raw-XML value (box compaction frees the space).
          await _cache.delete(_legacyKey);
          return right(encoded.length);
        },
      );
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, IList<EpgEntry>>> getAll() async {
    try {
      // Drop the v1 raw-XML value even if the re-sync below fails — leaving
      // it in place keeps the startup box scan slow on upgraded devices.
      await _cache.delete(_legacyKey);
      String? raw = await _cache.read(_key);
      if ((raw == null || raw.isEmpty) && !_resyncAttempted) {
        _resyncAttempted = true;
        final Either<Failures, int> resync = await sync();
        if (resync.isRight()) raw = await _cache.read(_key);
      }
      if (raw == null || raw.isEmpty) {
        return right(const IListConst<EpgEntry>(<EpgEntry>[]));
      }
      final List<EpgEntry> entries = await runParse(decodeEpgJson, raw);
      return right(entries.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}

// --- Top-level parsers (run via compute) ------------------------------------

/// Streaming XMLTV → pruned compact JSON rows
/// `[channelId, startMs, stopMs, title, description]`.
///
/// Event-based parsing on purpose: `XmlDocument.parse` builds a DOM several
/// times the size of the input, which OOM-kills 1.5GB TV devices on the
/// multi-day feeds providers ship.
String parseXmltvToJson(String xml) {
  final DateTime now = DateTime.now().toUtc();
  final DateTime lowerBound = now.subtract(_kEpgPastWindow);
  final DateTime upperBound = now.add(_kEpgFutureWindow);

  final List<List<dynamic>> rows = <List<dynamic>>[];
  bool inProgramme = false;
  String channel = "";
  DateTime? start;
  DateTime? stop;
  String title = "";
  String description = "";
  String? textTarget;
  final StringBuffer text = StringBuffer();

  for (final XmlEvent event in parseEvents(xml)) {
    switch (event) {
      case XmlStartElementEvent(:final String name):
        if (name == "programme") {
          inProgramme = true;
          channel = "";
          start = null;
          stop = null;
          title = "";
          description = "";
          for (final XmlEventAttribute a in event.attributes) {
            switch (a.name) {
              case "channel":
                channel = a.value;
              case "start":
                start = _parseXmltvTime(a.value);
              case "stop":
                stop = _parseXmltvTime(a.value);
            }
          }
          if (event.isSelfClosing) inProgramme = false;
        } else if (inProgramme &&
            (name == "title" || name == "desc") &&
            !event.isSelfClosing) {
          textTarget = name;
          text.clear();
        }
      case XmlTextEvent(:final String value):
        if (textTarget != null) text.write(value);
      case XmlCDATAEvent(:final String value):
        if (textTarget != null) text.write(value);
      case XmlEndElementEvent(:final String name):
        if (name == textTarget) {
          // Keep the first title/desc (feeds repeat them per language).
          if (textTarget == "title" && title.isEmpty) {
            title = text.toString().trim();
          } else if (textTarget == "desc" && description.isEmpty) {
            description = text.toString().trim();
            if (description.length > _kEpgDescriptionMaxChars) {
              description =
                  description.substring(0, _kEpgDescriptionMaxChars);
            }
          }
          textTarget = null;
        } else if (name == "programme") {
          inProgramme = false;
          textTarget = null;
          final DateTime? s = start;
          final DateTime? e = stop;
          if (channel.isNotEmpty &&
              s != null &&
              e != null &&
              e.isAfter(lowerBound) &&
              s.isBefore(upperBound)) {
            rows.add(<dynamic>[
              channel,
              s.millisecondsSinceEpoch,
              e.millisecondsSinceEpoch,
              title,
              description,
            ]);
          }
        }
      default:
        break;
    }
  }
  return jsonEncode(rows);
}

/// Decodes the compact JSON rows written by [parseXmltvToJson].
List<EpgEntry> decodeEpgJson(String raw) {
  final List<dynamic> rows = jsonDecode(raw) as List<dynamic>;
  return rows.map((dynamic r) {
    final List<dynamic> row = r as List<dynamic>;
    return EpgEntry(
      channelId: row[0] as String,
      start: DateTime.fromMillisecondsSinceEpoch(row[1] as int, isUtc: true),
      stop: DateTime.fromMillisecondsSinceEpoch(row[2] as int, isUtc: true),
      title: row[3] as String,
      description: row[4] as String,
    );
  }).toList();
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
