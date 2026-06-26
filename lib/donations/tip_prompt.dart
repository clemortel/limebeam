import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_donations/iptv_donations.dart";
import "package:iptv_settings/iptv_settings.dart";

import "../router/router.gr.dart";

/// Launches before the first contextual prompt may appear.
const int _kFirstPromptMinLaunches = 5;

/// Watch time (seconds) before the first contextual prompt may appear.
const int _kFirstPromptMinWatchSeconds = 1800;

/// Launches before the single follow-up reminder may appear.
const int _kSecondPromptMinLaunches = 20;

/// Pure eligibility rule for the contextual Tip Jar prompt — no side effects, so
/// it is trivially unit-testable. Never eligible for a supporter, with reminders
/// off, on the very first launch, or after the follow-up was already shown.
bool isTipPromptEligible({
  required bool supporter,
  required bool remindersEnabled,
  required int launchCount,
  required int watchSeconds,
  required bool shownOnce,
  required bool shownTwice,
}) {
  if (supporter || !remindersEnabled) return false;
  if (!shownOnce) {
    return launchCount >= _kFirstPromptMinLaunches &&
        watchSeconds >= _kFirstPromptMinWatchSeconds;
  }
  if (!shownTwice) return launchCount >= _kSecondPromptMinLaunches;
  return false;
}

/// Shows the rare, ignorable "support the dev" bottom sheet when earned.
///
/// Reads usage metrics fresh (the player writes watch time outside Riverpod),
/// shows at most once per app session, and persists that it was shown so a user
/// ever sees it once or twice — never after they have tipped.
class TipPromptService {
  const TipPromptService();

  static bool _shownThisSession = false;

  Future<void> maybeShow(BuildContext context, WidgetRef ref) async {
    if (_shownThisSession) return;

    final AppPreferences prefs = ref.read(appPreferencesNotifierProvider);
    final UsageMetrics usage =
        ref.read(usageMetricsRepositoryProvider).load();

    final bool eligible = isTipPromptEligible(
      supporter: prefs.supporter,
      remindersEnabled: prefs.donationReminders,
      launchCount: prefs.launchCount,
      watchSeconds: usage.watchTimeTotalSeconds,
      shownOnce: usage.tipPromptShownOnce,
      shownTwice: usage.tipPromptShownTwice,
    );
    if (!eligible) return;

    _shownThisSession = true;
    await ref.read(usageMetricsRepositoryProvider).markTipPromptShown();
    if (!context.mounted) return;

    final bool wantsToSupport = await TipPromptBottomSheet.show(context);
    if (wantsToSupport && context.mounted) {
      await context.router.root.push(const DonationsRoute());
    }
  }
}
