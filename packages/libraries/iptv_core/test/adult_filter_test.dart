import "package:flutter_test/flutter_test.dart";
import "package:iptv_core/iptv_core.dart";

void main() {
  group("isAdultCategoryName", () {
    test("flags adult markers", () {
      expect(isAdultCategoryName("XXX Movies"), isTrue);
      expect(isAdultCategoryName("Adultes 18+"), isTrue);
      expect(isAdultCategoryName("PORN HD"), isTrue);
      expect(isAdultCategoryName("Érotique"), isTrue);
    });

    test("leaves normal categories alone", () {
      expect(isAdultCategoryName("Sports"), isFalse);
      expect(isAdultCategoryName("Kids"), isFalse);
      expect(isAdultCategoryName("News & Documentaires"), isFalse);
    });
  });
}
