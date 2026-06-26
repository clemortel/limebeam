import "package:freezed_annotation/freezed_annotation.dart";

part "donation_product.freezed.dart";

/// A Tip Jar item. [id] is the store product id (consumable, platform-specific);
/// [price] is the store-localized price string resolved at load time.
/// [isRecommended] highlights one card in the UI (no functional difference).
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class DonationProduct with _$DonationProduct {
  const factory DonationProduct({
    required String id,
    required String title,
    required String subtitle,
    required String emoji,
    required String price,
    @Default(false) bool isRecommended,
  }) = _DonationProduct;
}
