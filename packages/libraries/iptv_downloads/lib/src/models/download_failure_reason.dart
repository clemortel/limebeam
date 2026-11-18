/// Why a download ended in failure. Typed so the UI can say something more
/// useful than "failed" and so a retry can pick the right advice.
enum DownloadFailureReason {
  /// Not enough room on the device, or the file could not be written.
  storage,

  /// No connection, or it dropped past the retry budget.
  network,

  /// The panel answered with an error, or cannot resume a paused transfer.
  server,

  /// Anything else, and records written before reasons existed.
  unknown,
}
