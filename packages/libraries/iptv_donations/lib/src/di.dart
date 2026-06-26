import "package:get_it/get_it.dart";
import "package:in_app_purchase/in_app_purchase.dart";

import "infrastructure/donation_repository.dart";

/// Registers the Tip Jar repository (platform billing). Call after registerCore.
void registerDonations(GetIt getIt) {
  getIt.registerLazySingleton<DonationRepository>(
    () => InAppPurchaseDonationRepository(InAppPurchase.instance),
  );
}
