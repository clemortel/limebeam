/// Compile-time environment values, supplied via --dart-define.
///
/// No magic strings scattered across the app: read configuration here.
abstract final class Env {
  /// Default request timeout for the http layer.
  static const Duration requestTimeout = Duration(seconds: 30);

  /// Optional fixed portal base URL injected at build time
  /// (empty when the user supplies their own portal).
  static const String defaultPortalUrl =
      String.fromEnvironment("PORTAL_URL", defaultValue: "");

  static const bool isProduction =
      bool.fromEnvironment("dart.vm.product", defaultValue: false);
}
