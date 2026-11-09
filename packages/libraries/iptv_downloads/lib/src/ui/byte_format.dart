import "package:iptv_l10n/iptv_l10n.dart";

import "../models/download_failure_reason.dart";

const int _kUnit = 1024;

/// Below MB a figure is whole; from MB up it gets decimals.
const int _kFirstDecimalIndex = 2;
const int _kDecimals = 1;
const List<String> _kSuffixes = <String>["B", "KB", "MB", "GB", "TB"];

/// "1.4 GB". Binary steps, one decimal from MB up, like the iOS storage page.
String formatBytes(int bytes) {
  double value = bytes.toDouble();
  int index = 0;
  while (value >= _kUnit && index < _kSuffixes.length - 1) {
    value /= _kUnit;
    index++;
  }
  final String number = index < _kFirstDecimalIndex
      ? value.round().toString()
      : value.toStringAsFixed(_kDecimals);
  return "$number ${_kSuffixes[index]}";
}

/// User-facing text for a typed failure reason.
String downloadFailureLabel(AppLocalizations l, DownloadFailureReason reason) =>
    switch (reason) {
      DownloadFailureReason.storage => l.downloadsReasonStorage,
      DownloadFailureReason.network => l.downloadsReasonNetwork,
      DownloadFailureReason.server => l.downloadsReasonServer,
      DownloadFailureReason.unknown => l.downloadsReasonUnknown,
    };
