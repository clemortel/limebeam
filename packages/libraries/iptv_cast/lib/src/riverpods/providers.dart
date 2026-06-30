import "package:get_it/get_it.dart";
import "package:iptv_cast/src/infrastructure/cast_repository.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered cast repository into Riverpod.
@Riverpod(keepAlive: true)
ICastRepository castRepository(Ref ref) =>
    GetIt.instance<ICastRepository>();
