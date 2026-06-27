/// iptv_donations — Tip Jar (support the developer) via in-app purchase.
///
/// Public surface only. Implementation stays private under `src/`.
library iptv_donations;

export "src/di.dart";
export "src/infrastructure/donation_repository.dart" show DonationRepository;
export "src/models/donation_product.dart";
export "src/riverpods/donation_products_notifier.dart";
export "src/riverpods/donation_purchase_notifier.dart";
export "src/riverpods/providers.dart";
export "src/ui/support_developer_view.dart";
export "src/ui/tip_prompt_bottom_sheet.dart";
export "src/ui/tip_thanks_bottom_sheet.dart";
