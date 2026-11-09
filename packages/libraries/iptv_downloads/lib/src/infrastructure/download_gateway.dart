import "dart:async";

import "package:background_downloader/background_downloader.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

import "../models/download_request.dart";

/// Native status of one transfer, reduced to what the repository needs.
enum GatewayStatus { queued, running, completed, failed, canceled }

/// One status or progress tick coming from the native layer.
class GatewayEvent {
  const GatewayEvent(this.taskId, this.status, [this.progress = 0]);

  /// The download key (`DownloadRecord.key`): the native task id.
  final String taskId;
  final GatewayStatus status;

  /// 0..1, meaningful while [status] is running.
  final double progress;
}

/// Thrown by the gateway instead of the plugin's own exceptions: their
/// messages may embed the task URL, which carries the Xtream password.
class DownloadGatewayException implements Exception {
  const DownloadGatewayException(this.operation);

  final String operation;

  @override
  String toString() => "DownloadGatewayException($operation)";
}

/// Thin seam over the native downloader so the repository runs in tests with
/// no platform channel.
abstract interface class DownloadGateway {
  Stream<GatewayEvent> get events;

  /// Configures the queue and starts listening. Must not touch the network.
  Future<void> initialize();

  /// Returns false when the native layer refused the task. The task id is
  /// the request key, so two sources never collide.
  Future<bool> enqueue(DownloadRequest request, String filename);

  Future<void> cancel(String taskId);

  /// Task ids (download keys) the native layer still knows about.
  Future<ISet<String>> activeIds();

  /// Best-effort: erases the plugin's stored copy of the task [taskId]
  /// (resume data, paused task), which embeds the credentialed URL. Never
  /// throws.
  Future<void> purgeStoredTask(String taskId);
}

/// Folder under the documents directory, shared with the repository.
const String kDownloadsDirectory = "downloads";
const String _kUserAgent = "VLC/3.0.20 LibVLC/3.0.20";
const int _kRetries = 5;

/// One transfer at a time through the native holding queue: it keeps
/// pulling the next episode while the app is suspended.
const (int, int, int) _kHoldingQueue = (1, 1, 1);

/// iOS kills a session after 4 h by default, less than a season.
const Duration _kResourceTimeout = Duration(days: 2);

/// [FileDownloader]-backed gateway.
///
/// Credential trap (background_downloader 9.5.9): the plugin serialises the
/// whole task, URL (Xtream user and password) included, in every store
/// below. None can be emptied through a public API. Paths are in the
/// plugin source; BD = BDPlugin, TR = TaskRunner, TF = TaskFunctions.swift,
/// PS = lib/src/persistent_storage.dart.
///
/// Android
///  - SharedPreferences `<applicationId>_preferences.xml` (the plugin uses
///    `getDefaultSharedPreferences`), key `...taskMap.v2` (BD.kt:316-321).
///    Written on each enqueue, removed at the final state, retries
///    included (TR.kt:283-292): a kill or crash mid-task leaves it. The same
///    file gets `statusUpdateMap.v2` / `resumeDataMap.v2` when Dart is
///    unreachable (TR.kt:253, 377), emptied at the next `start()`. In Auto
///    Backup unless excluded: we exclude it (res/xml backup rules).
///  - WorkManager input data (BD.kt:242), in the `androidx.work.workdb`
///    SQLite database. Lives until WorkManager prunes the finished work,
///    which we do not control. WorkManager 2.11 should keep the file in
///    `no_backup/` (never backed up); not checkable offline, so the same
///    file is excluded explicitly in case it sits in `databases/`.
///  - Dart local store, `files/backgroundDownloaderResumeData` and
///    `...PausedTasks` (PS.dart:381-383). Emptied by [purgeStoredTask]
///    after each end; stays after a kill. Excluded from backup too.
/// iOS
///  - Same Dart local store, in Library/Application Support (resume data
///    from a network error). Same lifetime. Backed up by iCloud and iTunes.
///  - UserDefaults (Library/Preferences) `statusUpdateMap.v2` and
///    `progressUpdateMap.v2` (TF.swift:428, 467, 555-560), plus a
///    `resumeDataMap.v2` fallback (TF.swift:496), written whenever the
///    background channel cannot reach Dart (app relaunched in the
///    background). Erased only by the next `start()` (BDPlugin.swift:698
///    -708). Library/Preferences CANNOT be excluded from backup, so on iOS
///    this copy can reach a device backup. No public API reaches it.
///
/// Residual, accepted by the owner on 2026-11-09: the URL can outlive a task in the
/// stores above. What our code does: no task tracking, purge of every store
/// we can reach after each end, and, when a source is deleted, the
/// repository cancels its tasks, purges them and deletes their files
/// (`DownloadsRepository.removeSource`).
class BackgroundDownloaderGateway implements DownloadGateway {
  /// Held so the purge reaches the very store the plugin writes to.
  final LocalStorePersistentStorage _storage = LocalStorePersistentStorage();

  final StreamController<GatewayEvent> _events =
      StreamController<GatewayEvent>.broadcast();

  @override
  Stream<GatewayEvent> get events => _events.stream;

  @override
  Future<void> initialize() async {
    try {
      // First FileDownloader() call of the app: the only one that may
      // inject the storage.
      await FileDownloader(persistentStorage: _storage).configure(
        globalConfig: <(String, dynamic)>[
          (Config.holdingQueue, _kHoldingQueue),
          (Config.resourceTimeout, _kResourceTimeout),
        ],
      );
      // Listener first: start() flushes updates from the suspended period.
      FileDownloader().updates.listen(_onUpdate);
      // No tracking: the task database would keep the URL after the end.
      // Resume data and paused tasks are not covered: see [purgeStoredTask].
      await FileDownloader().start(
        doTrackTasks: false,
        doRescheduleKilledTasks: false,
      );
    } catch (_) {
      throw const DownloadGatewayException("initialize");
    }
  }

  void _onUpdate(TaskUpdate update) {
    final String id = update.task.taskId;
    switch (update) {
      case TaskStatusUpdate():
        _events.add(GatewayEvent(id, _mapStatus(update.status)));
      case TaskProgressUpdate():
        // Negative values are terminal sentinels sent after the status
        // update, which already carries the truth.
        if (update.progress < 0) return;
        _events.add(GatewayEvent(id, GatewayStatus.running, update.progress));
    }
  }

  static GatewayStatus _mapStatus(TaskStatus status) => switch (status) {
        TaskStatus.enqueued ||
        TaskStatus.waitingToRetry ||
        TaskStatus.paused =>
          GatewayStatus.queued,
        TaskStatus.running => GatewayStatus.running,
        TaskStatus.complete => GatewayStatus.completed,
        TaskStatus.canceled => GatewayStatus.canceled,
        TaskStatus.failed || TaskStatus.notFound => GatewayStatus.failed,
      };

  @override
  Future<bool> enqueue(DownloadRequest request, String filename) async {
    try {
      return await FileDownloader().enqueue(
        DownloadTask(
          taskId: request.key,
          url: request.url,
          filename: filename,
          directory: kDownloadsDirectory,
          // Not Application Support: its path contains a space.
          baseDirectory: BaseDirectory.applicationDocuments,
          // Xtream panels block default agents.
          headers: const <String, String>{"User-Agent": _kUserAgent},
          updates: Updates.statusAndProgress,
          retries: _kRetries,
          allowPause: true,
          requiresWiFi: false,
        ),
      );
    } catch (_) {
      throw const DownloadGatewayException("enqueue");
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    try {
      await FileDownloader().cancelTaskWithId(taskId);
    } catch (_) {
      throw const DownloadGatewayException("cancel");
    }
  }

  @override
  Future<ISet<String>> activeIds() async {
    try {
      final List<Task> tasks = await FileDownloader().allTasks();
      return tasks.map((Task t) => t.taskId).toISet();
    } catch (_) {
      throw const DownloadGatewayException("activeIds");
    }
  }

  @override
  Future<void> purgeStoredTask(String taskId) async {
    try {
      await _storage.removeResumeData(taskId);
      await _storage.removePausedTask(taskId);
    } catch (_) {
      // Best effort, and never logged: nothing here may carry the URL.
    }
  }
}
