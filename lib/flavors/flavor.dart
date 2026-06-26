/// Build flavors. Maps 1:1 to injectable @Environment names and to the
/// environment string passed to `configureDependencies`.
enum Flavor {
  development,
  production;

  /// Injectable environment name for this flavor.
  String get environment => name;
}
