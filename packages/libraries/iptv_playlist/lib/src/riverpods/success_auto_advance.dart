import "dart:async";

import "package:riverpod_annotation/riverpod_annotation.dart";

part "success_auto_advance.g.dart";

/// How long the "source connected" summary stays before the app moves on.
const Duration kSuccessAutoAdvanceDelay = Duration(milliseconds: 2500);

/// Flips to true once the success summary has been readable long enough. The
/// screen listens and navigates; auto-dispose cancels the timer if the user
/// taps "Discover" first.
@riverpod
class SuccessAutoAdvance extends _$SuccessAutoAdvance {
  @override
  bool build() {
    final Timer timer = Timer(kSuccessAutoAdvanceDelay, () => state = true);
    ref.onDispose(timer.cancel);
    return false;
  }
}
