import "package:flutter_test/flutter_test.dart";
import "package:green_iptv/donations/tip_prompt.dart";

void main() {
  // Convenience wrapper with sensible "eligible" defaults so each test only
  // varies the field under scrutiny.
  bool eligible({
    bool supporter = false,
    bool remindersEnabled = true,
    int launchCount = 5,
    int watchSeconds = 1800,
    bool shownOnce = false,
    bool shownTwice = false,
  }) =>
      isTipPromptEligible(
        supporter: supporter,
        remindersEnabled: remindersEnabled,
        launchCount: launchCount,
        watchSeconds: watchSeconds,
        shownOnce: shownOnce,
        shownTwice: shownTwice,
      );

  group("first prompt", () {
    test("eligible at >=5 launches and >=30 min watched", () {
      expect(eligible(), isTrue);
    });

    test("not eligible with too few launches", () {
      expect(eligible(launchCount: 4), isFalse);
    });

    test("not eligible with too little watch time", () {
      expect(eligible(watchSeconds: 1799), isFalse);
    });

    test("never on the very first launch", () {
      expect(eligible(launchCount: 1, watchSeconds: 100000), isFalse);
    });
  });

  group("opt-outs", () {
    test("never for a supporter", () {
      expect(eligible(supporter: true), isFalse);
    });

    test("never when reminders are disabled", () {
      expect(eligible(remindersEnabled: false), isFalse);
    });
  });

  group("follow-up reminder", () {
    test("eligible once shown and >=20 launches", () {
      expect(eligible(shownOnce: true, launchCount: 20), isTrue);
    });

    test("not eligible once shown but below 20 launches", () {
      expect(eligible(shownOnce: true, launchCount: 19), isFalse);
    });

    test("never again after the second prompt", () {
      expect(
        eligible(shownOnce: true, shownTwice: true, launchCount: 999),
        isFalse,
      );
    });
  });
}
