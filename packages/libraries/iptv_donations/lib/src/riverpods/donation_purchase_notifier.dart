import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:iptv_core/iptv_core.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

import "../models/donation_product.dart";
import "providers.dart";

part "donation_purchase_notifier.g.dart";

/// Tracks the in-flight purchase. `success(true)` = paid, `success(false)` =
/// user canceled, `error` = store failure.
@riverpod
class DonationPurchaseNotifier extends _$DonationPurchaseNotifier {
  @override
  AsyncState<bool> build() => const AsyncState<bool>.idle();

  /// Starts a purchase; returns `true` only when actually paid (for the toast).
  Future<bool> buy(DonationProduct product) async {
    state = const AsyncState<bool>.loading();
    final Either<Failures, bool> result =
        await ref.read(donationRepositoryProvider).buy(product);
    return result.fold(
      (Failures failure) {
        state = AsyncState<bool>.error(failure);
        return false;
      },
      (bool purchased) {
        state = AsyncState<bool>.success(purchased);
        return purchased;
      },
    );
  }
}
