import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/donation_product.dart";
import "providers.dart";

part "donation_products_notifier.g.dart";

/// Loads the Tip Jar catalog (with store-localized prices). Long-lived.
@Riverpod(keepAlive: true)
class DonationProductsNotifier extends _$DonationProductsNotifier {
  @override
  AsyncState<IList<DonationProduct>> build() {
    _fetch();
    return const AsyncState<IList<DonationProduct>>.loading();
  }

  Future<void> _fetch() async {
    final Either<Failures, IList<DonationProduct>> result =
        await ref.read(donationRepositoryProvider).loadProducts();
    state = result.fold(
      (Failures failure) => AsyncState<IList<DonationProduct>>.error(failure),
      (IList<DonationProduct> products) =>
          AsyncState<IList<DonationProduct>>.success(products),
    );
  }

  Future<void> refresh() => _fetch();
}
