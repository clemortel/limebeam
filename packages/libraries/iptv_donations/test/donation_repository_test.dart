import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:flutter_test/flutter_test.dart";
import "package:in_app_purchase/in_app_purchase.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_donations/iptv_donations.dart";
// Concrete impl is intentionally hidden from the barrel; reach it for the test.
import "package:iptv_donations/src/infrastructure/donation_repository.dart";
import "package:mockito/annotations.dart";
import "package:mockito/mockito.dart";

import "donation_repository_test.mocks.dart";

// Run `dart run build_runner build` to generate the mocks.
@GenerateMocks(<Type>[InAppPurchase])
void main() {
  late MockInAppPurchase iap;
  late InAppPurchaseDonationRepository repository;

  // Apple ids (with dots) are what the iOS catalog queries.
  ProductDetails details(String id, String price) => ProductDetails(
        id: id,
        title: id,
        description: id,
        price: price,
        rawPrice: 0,
        currencyCode: "EUR",
      );

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    iap = MockInAppPurchase();
    repository = InAppPurchaseDonationRepository(iap);
  });

  tearDown(() => debugDefaultTargetPlatformOverride = null);

  test("loadProducts returns the 3 tips with ids, titles and recommendation",
      () async {
    when(iap.isAvailable()).thenAnswer((_) async => true);
    when(iap.queryProductDetails(any)).thenAnswer(
      (_) async => ProductDetailsResponse(
        productDetails: <ProductDetails>[
          details("tip.coffee", "1,19 €"),
          details("tip.meal", "4,99 €"),
          details("tip.devsession", "9,99 €"),
        ],
        notFoundIDs: const <String>[],
      ),
    );

    final Either<Failures, IList<DonationProduct>> result =
        await repository.loadProducts();

    final IList<DonationProduct> products =
        result.getOrElse(() => const IListConst<DonationProduct>(<DonationProduct>[]));
    expect(products.length, 3);
    expect(
      products.map((DonationProduct p) => p.id).toList(),
      <String>["tip.coffee", "tip.meal", "tip.devsession"],
    );
    expect(products[0].title, "Un café");
    expect(products[1].title, "Un repas");
    expect(products[2].title, "Grosse session dev");
    expect(products[1].price, "4,99 €");
    // Only the meal is highlighted.
    expect(products[0].isRecommended, isFalse);
    expect(products[1].isRecommended, isTrue);
    expect(products[2].isRecommended, isFalse);
  });

  test("loadProducts returns an empty list (not a failure) when store is empty",
      () async {
    when(iap.isAvailable()).thenAnswer((_) async => true);
    when(iap.queryProductDetails(any)).thenAnswer(
      (_) async => ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>["tip.coffee"],
      ),
    );

    final Either<Failures, IList<DonationProduct>> result =
        await repository.loadProducts();

    expect(result.isRight(), isTrue);
    expect(
      result.getOrElse(
        () => const IListConst<DonationProduct>(<DonationProduct>[]),
      ),
      isEmpty,
    );
  });

  test("loadProducts fails when billing is unavailable", () async {
    when(iap.isAvailable()).thenAnswer((_) async => false);

    final Either<Failures, IList<DonationProduct>> result =
        await repository.loadProducts();

    expect(result.isLeft(), isTrue);
  });

  test("buy returns a notFound failure when the product is gone", () async {
    when(iap.isAvailable()).thenAnswer((_) async => true);
    when(iap.queryProductDetails(any)).thenAnswer(
      (_) async => ProductDetailsResponse(
        productDetails: const <ProductDetails>[],
        notFoundIDs: const <String>["tip.coffee"],
      ),
    );

    final Either<Failures, bool> result = await repository.buy(
      const DonationProduct(
        id: "tip.coffee",
        title: "Un café",
        subtitle: "Juste pour dire merci",
        emoji: "☕",
        price: "1,19 €",
      ),
    );

    expect(result, left<Failures, bool>(const Failures.notFound()));
  });
}
