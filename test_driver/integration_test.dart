import "dart:io";

import "package:integration_test/integration_test_driver_extended.dart";

/// Driver for the store-screenshot harness. Run with:
///
///   flutter drive \
///     --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshots_test.dart \
///     -d <device_id>
///
/// Each `binding.takeScreenshot(name)` call lands as `screenshots/<name>.png`.
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (
      String name,
      List<int> bytes, [
      Map<String, Object?>? args,
    ]) async {
      final Directory dir = Directory("screenshots");
      if (!dir.existsSync()) dir.createSync(recursive: true);
      File("screenshots/$name.png").writeAsBytesSync(bytes);
      return true;
    },
  );
}
