import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";

import "sync_progress.dart";

/// What the sync gate did with a source change: it either refused it (a sync
/// is in flight) or ran it. Sealed so callers cannot forget the refusal.
sealed class SyncGateOutcome<T> {
  const SyncGateOutcome();
}

/// A sync was already in flight: nothing was changed.
final class SyncGateRefused<T> extends SyncGateOutcome<T> {
  const SyncGateRefused();
}

/// The change ran. [sync] is the sync started right after a successful
/// change (null when the change failed or needed none); await it instead of
/// calling `run()` again, which could start a second sync if it already ended.
final class SyncGateRan<T> extends SyncGateOutcome<T> {
  const SyncGateRan(this.result, {this.sync});

  final Either<Failures, T> result;
  final Future<SyncProgress>? sync;
}
