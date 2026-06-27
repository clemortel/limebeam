import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:freezed_annotation/freezed_annotation.dart";

part "media_track.freezed.dart";

/// Whether a [MediaTrack] carries audio or subtitles. Video tracks are not
/// user-selectable here, so they are deliberately absent.
enum TrackKind { audio, subtitle }

/// A single selectable audio or subtitle track exposed by the playback engine.
/// Engine types (media_kit / AVPlayer) never cross the package boundary; they
/// are mapped into this primitive model inside the infrastructure layer.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class MediaTrack with _$MediaTrack {
  const MediaTrack._();

  const factory MediaTrack({
    required String id,
    required TrackKind kind,
    String? title,
    String? language,
    @Default(false) bool isDefault,
  }) = _MediaTrack;

  /// Sentinel id meaning "no track" (disable audio / hide subtitles).
  static const String noneId = "no";

  /// Sentinel id meaning "let the engine pick the default track".
  static const String autoId = "auto";

  /// Best human label for the track row: explicit title, else language, else a
  /// generic fallback handled by the caller.
  String? get label => title ?? language;
}

/// The audio + subtitle tracks available for the current item plus the ids of
/// the currently-selected ones. Bundled so the notifier mutates one value.
///
/// Run `melos run build_runner` after editing.
@freezed
sealed class PlayerTracks with _$PlayerTracks {
  const PlayerTracks._();

  const factory PlayerTracks({
    @Default(IListConst<MediaTrack>(<MediaTrack>[])) IList<MediaTrack> audio,
    @Default(IListConst<MediaTrack>(<MediaTrack>[])) IList<MediaTrack> subtitle,
    String? selectedAudioId,
    String? selectedSubtitleId,
  }) = _PlayerTracks;

  /// True when there is at least one selectable track of either kind — the UI
  /// hides the track button entirely otherwise.
  bool get hasAny => audio.isNotEmpty || subtitle.isNotEmpty;

  /// True when a subtitle track other than "off" is currently selected.
  bool get hasSubtitleOn =>
      selectedSubtitleId != null && selectedSubtitleId != MediaTrack.noneId;
}

/// First track whose language matches [language], case-insensitive and tolerant
/// of code-length variants ("en"/"eng") and region suffixes ("en-US"). Returns
/// null when none match. Pure so it can be unit-tested without an engine.
MediaTrack? matchTrackByLanguage(IList<MediaTrack> tracks, String language) {
  final String want = language.toLowerCase();
  for (final MediaTrack track in tracks) {
    final String? lang = track.language?.toLowerCase();
    if (lang == null) continue;
    if (lang == want || lang.startsWith(want) || want.startsWith(lang)) {
      return track;
    }
  }
  return null;
}
