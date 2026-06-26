import "bootstrap.dart";
import "flavors/flavor.dart";

/// Default entrypoint (`flutter run` with no --target) → development flavor.
/// Use lib/main_development.dart or lib/main_production.dart to be explicit.
Future<void> main() => bootstrap(Flavor.development);
