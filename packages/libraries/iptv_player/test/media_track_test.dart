import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_test/flutter_test.dart";
import "package:iptv_player/iptv_player.dart";

void main() {
  IList<MediaTrack> audio(List<MediaTrack> tracks) => tracks.toIList();

  group("PlayerTracks", () {
    test("should report hasAny false when both lists are empty", () {
      const PlayerTracks tracks = PlayerTracks();
      expect(tracks.hasAny, isFalse);
    });

    test("should report hasAny true when an audio track exists", () {
      final PlayerTracks tracks = PlayerTracks(
        audio: audio(const <MediaTrack>[
          MediaTrack(id: "1", kind: TrackKind.audio, language: "eng"),
        ]),
      );
      expect(tracks.hasAny, isTrue);
    });

    test("should report hasSubtitleOn false when selection is null or 'no'",
        () {
      const PlayerTracks none = PlayerTracks();
      const PlayerTracks off =
          PlayerTracks(selectedSubtitleId: MediaTrack.noneId);
      expect(none.hasSubtitleOn, isFalse);
      expect(off.hasSubtitleOn, isFalse);
    });

    test("should report hasSubtitleOn true for a real selection", () {
      const PlayerTracks on = PlayerTracks(selectedSubtitleId: "2");
      expect(on.hasSubtitleOn, isTrue);
    });
  });

  group("MediaTrack.label", () {
    test("should prefer the title", () {
      const MediaTrack track = MediaTrack(
        id: "1",
        kind: TrackKind.audio,
        title: "English 5.1",
        language: "eng",
      );
      expect(track.label, "English 5.1");
    });

    test("should fall back to language when there is no title", () {
      const MediaTrack track =
          MediaTrack(id: "1", kind: TrackKind.subtitle, language: "fra");
      expect(track.label, "fra");
    });
  });

  group("matchTrackByLanguage", () {
    final IList<MediaTrack> tracks = audio(const <MediaTrack>[
      MediaTrack(id: "1", kind: TrackKind.audio, language: "eng"),
      MediaTrack(id: "2", kind: TrackKind.audio, language: "fra"),
      MediaTrack(id: "3", kind: TrackKind.audio, language: "es-ES"),
    ]);

    test("should match an exact language code", () {
      expect(matchTrackByLanguage(tracks, "fra")?.id, "2");
    });

    test("should match across code-length variants (en vs eng)", () {
      expect(matchTrackByLanguage(tracks, "en")?.id, "1");
    });

    test("should match a region-suffixed code by prefix", () {
      expect(matchTrackByLanguage(tracks, "es")?.id, "3");
    });

    test("should be case-insensitive", () {
      expect(matchTrackByLanguage(tracks, "FRA")?.id, "2");
    });

    test("should return null when nothing matches", () {
      expect(matchTrackByLanguage(tracks, "deu"), isNull);
    });
  });
}
