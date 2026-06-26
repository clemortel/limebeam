import "bootstrap.dart";
import "flavors/flavor.dart";

/// Development flavor entrypoint.
/// Run: flutter run --target lib/main_development.dart
Future<void> main() => bootstrap(Flavor.development);
