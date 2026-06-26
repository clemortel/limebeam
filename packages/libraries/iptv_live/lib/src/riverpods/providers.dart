import "package:get_it/get_it.dart";
import "package:iptv_live/src/infrastructure/live_repository.dart";
import "package:riverpod_annotation/riverpod_annotation.dart";

part "providers.g.dart";

/// Bridges the GetIt-registered repository into Riverpod.
@Riverpod(keepAlive: true)
ILiveRepository liveRepository(LiveRepositoryRef ref) =>
    GetIt.instance<ILiveRepository>();

/// Currently selected category id for the channel list ("" = all).
@riverpod
class SelectedLiveCategory extends _$SelectedLiveCategory {
  @override
  String build() => "";

  void select(String categoryId) => state = categoryId;
}

/// TV tab layout: a vertical list (§4.3.1) or the EPG guide grid (§4.3.2).
enum LiveViewMode { list, guide }

@riverpod
class LiveViewModeNotifier extends _$LiveViewModeNotifier {
  @override
  LiveViewMode build() => LiveViewMode.list;

  void toggle() => state =
      state == LiveViewMode.list ? LiveViewMode.guide : LiveViewMode.list;
}
