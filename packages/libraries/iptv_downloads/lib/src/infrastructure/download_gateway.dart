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
    this.contentId,
    this.status, [
    this.progress = 0,
    this.reason = DownloadFailureReason.unknown,
  ]);

  final String contentId;
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

  /// Returns false when the native layer refused the task.
  Future<bool> enqueue(DownloadRequest request, String filename);

  Future<void> cancel(String contentId);

  /// False when the native layer cannot pause this transfer.
  Future<bool> pause(String contentId);

  /// False when there is nothing to resume (task unknown after a restart).
  Future<bool> resume(String contentId);

  /// Size announced by the server (HEAD), null when unknown or unreachable.
  Future<int?> expectedSize(DownloadRequest request);

  /// Ids of transfers the native layer still knows about.
  Future<ISet<String>> activeIds();
}

const String _kDirectory = "downloads";
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
class BackgroundDownloaderGateway implements DownloadGateway {
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
      await FileDownloader().configure(
        globalConfig: <(String, dynamic)>[
          (Config.holdingQueue, _kHoldingQueue),
          (Config.resourceTimeout, _kResourceTimeout),
        ],
      );
      // Listener first: start() flushes updates from the suspended period.
      FileDownloader().updates.listen(_onUpdate);
      // No tracking: the plugin database would keep the URL after the end.
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
        taskId: request.contentId,
        url: request.url,
        filename: filename,
        directory: _kDirectory,
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
      _tasks[request.contentId] = task;
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

  @override
  Future<bool> pause(String contentId) async {
    final DownloadTask? task = _tasks[contentId];
    if (task == null) return false;
    try {
      return await FileDownloader().pause(task);
    } catch (_) {
      throw const DownloadGatewayException("pause");
    }
  }

  @override
  Future<bool> resume(String contentId) async {
    final DownloadTask? task = _tasks[contentId];
    if (task == null) return false;
    try {
      return await FileDownloader().resume(task);
    } catch (_) {
      throw const DownloadGatewayException("resume");
    }
  }

  @override
  Future<void> cancel(String contentId) async {
    try {
      _tasks.remove(contentId);
      await FileDownloader().cancelTaskWithId(contentId);
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
}
