/// Why a form field is invalid. The view maps it to localized copy, so the
/// notifiers never carry user-facing strings.
enum FormFieldIssue { required, invalidUrl }

/// Shared URL check for the Xtream host and the M3U / EPG addresses.
FormFieldIssue? validateUrlField(String value) {
  final String v = value.trim();
  if (v.isEmpty) return FormFieldIssue.required;
  final Uri? uri = Uri.tryParse(v.contains("://") ? v : "http://$v");
  if (uri == null || uri.host.isEmpty) return FormFieldIssue.invalidUrl;
  return null;
}
