import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/foundation.dart";
import "package:in_app_purchase/in_app_purchase.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/donation_product.dart";

/// One Tip Jar catalog entry. [appleId]/[googleId] are the **product ids** the
/// app queries (Apple uses dots; Google Play product ids allow lowercase,
/// digits, underscores and dots — NOT hyphens). The Play "purchase option id"
/// is a separate sub-id (hyphens) the app never queries. Price/title come from
/// the store at load.
@immutable
class _TipItem {
  const _TipItem({
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.appleId,
    required this.googleId,
    this.isRecommended = false,
  });

  final String title;
  final String subtitle;
  final String emoji;
  final String appleId;
  final String googleId;
  final bool isRecommended;

  /// The store product id for the current platform.
  String get storeId =>
      defaultTargetPlatform == TargetPlatform.iOS ? appleId : googleId;
}

/// Consumable tip catalog. Order here is the display order in the Tip Jar.
/// Configure the matching ids in App Store Connect / Play Console.
const List<_TipItem> _kCatalog = <_TipItem>[
  _TipItem(
    title: "Un café",
    subtitle: "Juste pour dire merci",
    emoji: "☕",
    appleId: "tip.coffee",
    googleId: "tip_coffee",
  ),
  _TipItem(
    title: "Un repas",
    subtitle: "Tu soutiens vraiment le projet",
    emoji: "🍱",
    appleId: "tip.meal",
    googleId: "tip_meal",
    isRecommended: true,
  ),
  _TipItem(
    title: "Grosse session dev",
    subtitle: "Pour pousser une nouvelle fonctionnalité",
    emoji: "💻",
    appleId: "tip.devsession",
    googleId: "tip_devsession",
  ),
];

/// Tip Jar data layer. Pure client-side: talks only to the platform billing
/// service via [InAppPurchase]. Returns `Either<Failures, T>` and never throws.
abstract interface class DonationRepository {
  /// Loads the configured tip products with store-localized prices. Returns an
  /// empty list (not a failure) when the store has no matching products yet.
  Future<Either<Failures, IList<DonationProduct>>> loadProducts();

  /// Starts a consumable purchase. Resolves to `true` on success, `false` when
  /// the user cancels, or a [Failures] on store error.
  Future<Either<Failures, bool>> buy(DonationProduct product);
}

class InAppPurchaseDonationRepository implements DonationRepository {
  InAppPurchaseDonationRepository(this._iap);

  final InAppPurchase _iap;

  @override
  Future<Either<Failures, IList<DonationProduct>>> loadProducts() async {
    try {
      if (!await _iap.isAvailable()) return left(const Failures.unexpected());
      final Set<String> ids = <String>{
        for (final _TipItem item in _kCatalog) item.storeId,
      };
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(ids);
      final Map<String, ProductDetails> byId = <String, ProductDetails>{
        for (final ProductDetails p in response.productDetails) p.id: p,
      };
      final List<DonationProduct> products = <DonationProduct>[];
      for (final _TipItem item in _kCatalog) {
        final ProductDetails? details = byId[item.storeId];
        if (details == null) continue; // not yet configured in the store
        products.add(
          DonationProduct(
            id: item.storeId,
            title: item.title,
            subtitle: item.subtitle,
            emoji: item.emoji,
            price: details.price,
            isRecommended: item.isRecommended,
          ),
        );
      }
      return right(products.toIList());
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }

  @override
  Future<Either<Failures, bool>> buy(DonationProduct product) async {
    try {
      if (!await _iap.isAvailable()) return left(const Failures.unexpected());
      final ProductDetailsResponse response =
          await _iap.queryProductDetails(<String>{product.id});
      if (response.productDetails.isEmpty) {
        return left(const Failures.notFound());
      }
      final ProductDetails details = response.productDetails.first;

      final Completer<Either<Failures, bool>> completer =
          Completer<Either<Failures, bool>>();
      late final StreamSubscription<List<PurchaseDetails>> sub;
      sub = _iap.purchaseStream.listen((List<PurchaseDetails> purchases) async {
        for (final PurchaseDetails p in purchases) {
          if (p.productID != product.id) continue;
          switch (p.status) {
            case PurchaseStatus.purchased || PurchaseStatus.restored:
              if (p.pendingCompletePurchase) await _iap.completePurchase(p);
              if (!completer.isCompleted) completer.complete(right(true));
            case PurchaseStatus.canceled:
              if (!completer.isCompleted) completer.complete(right(false));
            case PurchaseStatus.error:
              if (!completer.isCompleted) {
                completer.complete(left(const Failures.unexpected()));
              }
            case PurchaseStatus.pending:
              break;
          }
        }
      });

      await _iap.buyConsumable(
        purchaseParam: PurchaseParam(productDetails: details),
      );
      final Either<Failures, bool> result = await completer.future;
      await sub.cancel();
      return result;
    } catch (error, stackTrace) {
      return left(catchError(error, stackTrace));
    }
  }
}
