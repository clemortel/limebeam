import "package:iptv_l10n/iptv_l10n.dart";

import "../models/form_field_issue.dart";

/// Localized message for a field issue; null when the field is valid.
extension FormFieldIssueText on FormFieldIssue? {
  String? text(AppLocalizations l) => switch (this) {
        null => null,
        FormFieldIssue.required => l.onboardingErrorRequired,
        FormFieldIssue.invalidUrl => l.onboardingErrorInvalidUrl,
      };
}
