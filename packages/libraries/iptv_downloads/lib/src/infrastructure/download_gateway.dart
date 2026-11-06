import "dart:async";

import "package:background_downloader/background_downloader.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";

import "../models/download_request.dart";

/// Native status of one transfer, reduced to what the repository needs.
enum GatewayStatus { queued, running, completed, failed, canceled }

/// One status or progress tick coming from the native layer.
class GatewayEvent {
  const GatewayEvent(this.contentId, this.status, [this.progress = 0]);

  final String contentId;
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

  /// Returns false when the native layer refused the task.
  Future<bool> enqueue(DownloadRequest request, String filename);

  Future<void> cancel(String contentId);

  /// Ids of transfers the native layer still knows about.
  Future<ISet<String>> activeIds();
}

const String _kDirectory = "downloads";
const String _kUserAgent = "VLC/3.0.20 LibVLC/3.0.20";
const int _kRetries = 5;

/// One transfer at a time through the native holding queue: it keeps
/// pulling the next episode while the app is suspended.
const (int, int, int) _kHoldingQueue = (1, 1, 1);

/// iOS kills a session after 4 h by default, less than a season.
const Duration _kResourceTimeout = Duration(days: 2);

/// [FileDownloader]-backed gateway.
class BackgroundDownloaderGateway implements DownloadGateway {
  final StreamController<GatewayEvent> _events =
      StreamController<GatewayEvent>.broadcast();

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
        _events.add(GatewayEvent(id, _mapStatus(update.status)));
      case TaskProgressUpdate():
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
        ),
      );
    } catch (_) {
      throw const DownloadGatewayException("enqueue");
    }
  }

  @override
  Future<void> cancel(String contentId) async {
    try {
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
