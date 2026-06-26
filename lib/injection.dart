import "package:get_it/get_it.dart";
import "package:iptv_api/iptv_api.dart";
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_donations/iptv_donations.dart";
import "package:iptv_epg/iptv_epg.dart";
import "package:iptv_favorites/iptv_favorites.dart";
import "package:iptv_live/iptv_live.dart";
import "package:iptv_series/iptv_series.dart";
import "package:iptv_settings/iptv_settings.dart";
import "package:iptv_vod/iptv_vod.dart";

/// Global service locator. Each package exposes a `register*` function that
/// registers its own (private) concretes — wiring is explicit and codegen-free
/// so it works reliably across the monorepo. Riverpod sits on top for state.
final GetIt getIt = GetIt.instance;

/// Builds the dependency graph. Requires `Hive.initFlutter()` to have run.
Future<void> configureDependencies() async {
  await registerCore(getIt); // cache box + ActiveSourceStore (must be first)
  await registerSettings(getIt); // preferences box (theme/font/parental)
  registerApi(getIt); // HttpService + PlaylistSourceFactory
  registerAuth(getIt); // secure storage + SourceRepository
  registerLive(getIt);
  registerVod(getIt);
  registerSeries(getIt);
  registerEpg(getIt);
  registerFavorites(getIt); // continue-watching + favorites store
  registerDonations(getIt); // Tip Jar (platform billing)
  registerCast(getIt); // Chromecast / AirPlay handoff
}
