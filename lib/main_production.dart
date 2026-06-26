import "bootstrap.dart";
import "flavors/flavor.dart";

/// Production flavor entrypoint.
/// Run: flutter run --target lib/main_production.dart
Future<void> main() => bootstrap(Flavor.production);
