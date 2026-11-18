import "dart:async";

import "package:get_it/get_it.dart";
import "package:hive_flutter/hive_flutter.dart";
import "package:path_provider/path_provider.dart";

import "infrastructure/download_gateway.dart";
import "infrastructure/download_storage.dart";
import "infrastructure/downloads_repository.dart";
import "infrastructure/downloads_repository_impl.dart";

const String _kBoxName = "downloads";

Future<String> _documentsPath() async =>
    (await getApplicationDocumentsDirectory()).path;

/// Registers the downloads repository and opens its own Hive box. Trap: not
/// the shared cache box, whose aggressive compaction suits catalog payloads.
///
/// Trap: no network and no wait on the native layer here, the app must boot
/// in airplane mode; the downloader initialises in the background.
Future<void> registerDownloads(GetIt getIt) async {
  final Box<String> box = await Hive.openBox<String>(_kBoxName);
  final DownloadsRepository repository = DownloadsRepository(
    box: box,
    gateway: BackgroundDownloaderGateway(),
    storage: ChannelDownloadStorage(),
    documentsPath: _documentsPath,
  );
  getIt.registerSingleton<IDownloadsRepository>(repository);
  unawaited(repository.initialize());
}
