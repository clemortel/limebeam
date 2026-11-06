import "package:get_it/get_it.dart";

/// Registers the downloads repository and opens its own Hive box. Trap: not
/// the shared cache box, whose aggressive compaction suits catalog payloads.
Future<void> registerDownloads(GetIt getIt) async {
  // Implemented by the engine lot.
}
