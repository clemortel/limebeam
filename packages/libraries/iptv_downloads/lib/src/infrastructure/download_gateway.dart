import "dart:async";

import "package:background_downloader/background_downloader.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

import "../models/download_failure_reason.dart";
import "../models/download_request.dart";

/// Native status of one transfer, reduced to what the repository needs.
enum GatewayStatus { queued, running, paused, completed, failed, canceled }

/// One status or progress tick coming from the native layer.
class GatewayEvent {
  const GatewayEvent(
    this.taskId,
    this.status, [
    this.progress = 0,
    this.reason = DownloadFailureReason.unknown,
  ]);

  /// The download key (`DownloadRecord.key`): the native task id.
  final String taskId;
  final GatewayStatus status;

  /// 0..1, meaningful while [status] is running.
  final double progress;

  /// Meaningful while [status] is failed.
  final DownloadFailureReason reason;
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

  /// False when the native layer cannot pause this transfer.
  Future<bool> pause(String taskId);

  /// False when there is nothing to resume (task unknown after a restart).
  Future<bool> resume(String taskId);

  /// Size announced by the server (HEAD), null when unknown or unreachable.
  Future<int?> expectedSize(DownloadRequest request);

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

/// A size probe must not stall an enqueue on a dead network.
const Duration _kProbeTimeout = Duration(seconds: 5);

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
///    from a network error). Same lifetime. Excluded from backup since lot B
///    (see the pause note below).
///  - UserDefaults (Library/Preferences) `statusUpdateMap.v2` and
///    `progressUpdateMap.v2` (TF.swift:428, 467, 555-560), plus a
///    `resumeDataMap.v2` fallback (TF.swift:496), written whenever the
///    background channel cannot reach Dart (app relaunched in the
///    background). Erased only by the next `start()` (BDPlugin.swift:698
///    -708). Library/Preferences CANNOT be excluded from backup, so on iOS
///    this copy can reach a device backup. No public API reaches it.
///
/// Pause (lot B) adds to these stores: a paused task is written whole to the
/// Dart local store `backgroundDownloaderPausedTasks`, and the iOS resume
/// data to `backgroundDownloaderResumeData` (PS.dart:381-383), both in
/// Application Support. They live until the task ends: [purgeStoredTask]
/// runs on completed, failed, canceled, on a resume that cannot continue,
/// on remove and on the boot reconcile. A paused download kept across
/// launches therefore keeps its URL there until resumed or deleted. That
/// folder is now excluded from iCloud backup (`ChannelDownloadStorage`),
/// which closes the "Dart local store backed up on iOS" item below.
///
/// Residual, accepted by the owner on 2026-11-09: the URL can outlive a task
/// in the stores above. What our code does: no task tracking, purge of every
/// store we can reach after each end, and, when a source is deleted, the
/// repository cancels its tasks, purges them and deletes their files
/// (`DownloadsRepository.removeSource`).
class BackgroundDownloaderGateway implements DownloadGateway {
  /// Held so the purge reaches the very store the plugin writes to.
  final LocalStorePersistentStorage _storage = LocalStorePersistentStorage();

  final StreamController<GatewayEvent> _events =
      StreamController<GatewayEvent>.broadcast();

  /// Tasks of this launch: pause and resume need the task object. Transfers
  /// from a previous launch are not tracked (the repository reconciles).
  final Map<String, DownloadTask> _tasks = <String, DownloadTask>{};

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
        _events.add(
          GatewayEvent(
            id,
            _mapStatus(update.status),
            0,
            _mapReason(update.exception),
          ),
        );
      case TaskProgressUpdate():
        // Negative values are sentinels (paused is sent BEFORE its status):
        // only statuses move the state machine.
        if (update.progress < 0) return;
        _events.add(GatewayEvent(id, GatewayStatus.running, update.progress));
    }
  }

  static GatewayStatus _mapStatus(TaskStatus status) => switch (status) {
        TaskStatus.enqueued ||
        TaskStatus.waitingToRetry =>
          GatewayStatus.queued,
        TaskStatus.paused => GatewayStatus.paused,
        TaskStatus.running => GatewayStatus.running,
        TaskStatus.complete => GatewayStatus.completed,
        TaskStatus.canceled => GatewayStatus.canceled,
        TaskStatus.failed || TaskStatus.notFound => GatewayStatus.failed,
      };

  static DownloadFailureReason _mapReason(TaskException? exception) =>
      switch (exception) {
        TaskFileSystemException() => DownloadFailureReason.storage,
        TaskConnectionException() => DownloadFailureReason.network,
        TaskHttpException() ||
        TaskResumeException() =>
          DownloadFailureReason.server,
        _ => DownloadFailureReason.unknown,
      };

  DownloadTask _taskFor(DownloadRequest request, String filename) =>
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
      );

  @override
  Future<bool> enqueue(DownloadRequest request, String filename) async {
    try {
      final DownloadTask task = _taskFor(request, filename);
      _tasks[request.key] = task;
      return await FileDownloader().enqueue(task);
    } catch (_) {
      throw const DownloadGatewayException("enqueue");
    }
  }

  @override
  Future<int?> expectedSize(DownloadRequest request) async {
    try {
      final int size = await _taskFor(request, "probe")
          .expectedFileSize()
          .timeout(_kProbeTimeout);
      // -1: the panel sent no Content-Length. Unknown means accepted.
      return size < 0 ? null : size;
    } catch (_) {
      return null;
    }
  }

  /// This launch's task, else the plugin's own copy: a task paused before
  /// a relaunch is only known to it.
  Future<DownloadTask?> _find(String taskId) async {
    final DownloadTask? known = _tasks[taskId];
    if (known != null) return known;
    final Task? stored = await FileDownloader().taskForId(taskId);
    return stored is DownloadTask ? stored : null;
  }

  @override
  Future<bool> pause(String taskId) async {
    try {
      final DownloadTask? task = await _find(taskId);
      if (task == null) return false;
      return await FileDownloader().pause(task);
    } catch (_) {
      throw const DownloadGatewayException("pause");
    }
  }

  @override
  Future<bool> resume(String taskId) async {
    try {
      final DownloadTask? task = await _find(taskId);
      if (task == null) return false;
      return await FileDownloader().resume(task);
    } catch (_) {
      throw const DownloadGatewayException("resume");
    }
  }

  @override
  Future<void> cancel(String taskId) async {
    try {
      _tasks.remove(taskId);
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
