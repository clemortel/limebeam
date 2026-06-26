import "package:injectable/injectable.dart";

import "source_config.dart";

/// In-memory holder for the currently-active source. Set by iptv_auth on
/// connect / hydrated on launch; read by feature repositories to know which
/// provider to talk to. Pure holder — no I/O, no persistence.
@lazySingleton
class ActiveSourceStore {
  SourceConfig? _config;
  String? _sourceId;

  /// Currently active source config, or null when none is connected.
  SourceConfig? get config => _config;

  /// Persisted id of the active source (matches the Hive metadata key).
  String? get sourceId => _sourceId;

  bool get hasActive => _config != null;

  void set({required String sourceId, required SourceConfig config}) {
    _sourceId = sourceId;
    _config = config;
  }

  void clear() {
    _sourceId = null;
    _config = null;
  }
}
