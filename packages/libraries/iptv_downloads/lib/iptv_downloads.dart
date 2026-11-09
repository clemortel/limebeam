/// iptv_downloads — offline episodes: queue, storage, and offline library.
library;

export "src/di.dart";
export "src/infrastructure/downloads_repository.dart"
    show IDownloadsRepository;
export "src/models/download_failure_reason.dart";
export "src/models/download_phase.dart";
export "src/models/download_record.dart";
export "src/models/download_request.dart";
export "src/models/download_storage_info.dart";
export "src/riverpods/providers.dart";
export "src/ui/downloads_view.dart";
export "src/ui/episode_download_button.dart";
export "src/ui/season_download_button.dart";
