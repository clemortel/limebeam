/// iptv_live — live channels + categories.
///
/// Reference implementation of the 4-layer pattern (models / infrastructure /
/// riverpods / ui). Mirror this structure in the other feature libraries.
library iptv_live;

export "src/di.dart";
export "src/infrastructure/live_repository.dart" show ILiveRepository;
export "src/models/channel.dart";
export "src/models/live_category.dart";
export "src/riverpods/live_categories_notifier.dart";
export "src/riverpods/live_channels_notifier.dart";
export "src/riverpods/providers.dart";
export "src/ui/live_channels_view.dart";
