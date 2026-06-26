import "package:riverpod_annotation/riverpod_annotation.dart";

part "parental_session.g.dart";

/// In-memory unlock state for parental control. Always locked at launch; set
/// to unlocked once the user enters the PIN. Not persisted — re-locks on every
/// app restart. Adult content is hidden while `parentalEnabled && !unlocked`.
@Riverpod(keepAlive: true)
class ParentalSession extends _$ParentalSession {
  @override
  bool build() => false;

  void unlock() => state = true;

  void lock() => state = false;
}
