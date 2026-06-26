/// Adult-content detection. Xtream/M3U don't flag adult categories, so we
/// match common name markers. Used at parse time to set `isAdult` on
/// categories and at filter time when parental control is locked.
final RegExp _kAdultPattern = RegExp(
  r"(adult|adulte|xxx|porn|18\+|\+18|\bsex\b|[eé]rot|nsfw)",
  caseSensitive: false,
);

/// Whether a category name looks like adult / 18+ content.
bool isAdultCategoryName(String name) => _kAdultPattern.hasMatch(name);
