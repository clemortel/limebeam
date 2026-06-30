import "package:get_it/get_it.dart";
import "package:iptv_donations/src/infrastructure/donation_repository.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
DonationRepository donationRepository(Ref ref) =>
    GetIt.instance<DonationRepository>();
