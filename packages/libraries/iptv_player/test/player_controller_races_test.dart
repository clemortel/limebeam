import "dart:async";

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/widgets.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:iptv_cast/iptv_cast.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_player/src/domain/playback_engine.dart";
import "package:iptv_player/src/domain/playback_queue.dart";
import "package:iptv_player/src/domain/playback_request.dart";
import "package:iptv_player/src/domain/subtitle_style.dart";
import "package:iptv_player/src/riverpods/player_controller.dart";
import "package:iptv_player/src/riverpods/player_ui_state.dart";

/// Engine double: records calls, optionally parks `dispose` on a gate.
class _FakeEngine implements PlaybackEngine {
  _FakeEngine({this.disposeGate});

  final Completer<void>? disposeGate;
  final List<String> opened = <String>[];
  int playOrPauseCalls = 0;
  bool disposed = false;

  @override
  Stream<Duration> get position => const Stream<Duration>.empty();
  @override
  Stream<Duration> get duration => const Stream<Duration>.empty();
  @override
  Stream<Duration> get buffer => const Stream<Duration>.empty();
  @override
  Stream<bool> get playing => const Stream<bool>.empty();
  @override
  Stream<bool> get buffering => const Stream<bool>.empty();
  @override
  Stream<bool> get completed => const Stream<bool>.empty();
  @override
  Stream<String> get error => const Stream<String>.empty();
  @override
  Stream<AvailableTracks> get tracks => const Stream<AvailableTracks>.empty();
  @override
  Stream<SelectedTrackIds> get selectedTracks =>
      const Stream<SelectedTrackIds>.empty();
  @override
  Stream<String> get subtitleCues => const Stream<String>.empty();
  @override
  double get volume => 100;
  @override
  bool get supportsSyncOffsets => false;
  @override
  Future<void> open(String url) async => opened.add(url);
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> playOrPause() async => playOrPauseCalls++;
  @override
  Future<void> seek(Duration position) async {}
  @override
  Future<void> setVolume(double volume) async {}
  @override
  Future<void> setAudioTrack(String id) async {}
  @override
  Future<void> setSubtitleTrack(String id) async {}
  @override
  Future<void> setSubtitleDelay(int milliseconds) async {}
  @override
  Future<void> setAudioDelay(int milliseconds) async {}
  @override
  Future<void> applySubtitleStyle(SubtitleStyle style) async {}
  @override
  Future<void> setFill(bool fill) async {}
  @override
  Widget buildView() => const SizedBox.shrink();
  @override
  Future<void> dispose() async {
    await disposeGate?.future;
    disposed = true;
  }
}

/// Cast double: `connectAndLoad` parks until the test completes it.
class _FakeCastRepo implements ICastRepository {
  final List<Completer<Either<Failures, Unit>>> loads =
      <Completer<Either<Failures, Unit>>>[];
  int endSessionCalls = 0;

  @override
  Future<Either<Failures, Unit>> connectAndLoad(
    CastDevice device, {
    required String url,
    required String title,
    required String contentType,
    required Duration startAt,
    required bool isLive,
    String? subtitle,
    String? posterUrl,
  }) {
    final Completer<Either<Failures, Unit>> load =
        Completer<Either<Failures, Unit>>();
    loads.add(load);
    return load.future;
  }

  @override
  Future<Duration> endSession() async {
    endSessionCalls++;
    return Duration.zero;
  }

  @override
  Stream<bool> connection() => const Stream<bool>.empty();
  @override
  Duration get position => Duration.zero;
  @override
  Future<void> initialize() async {}
  @override
  void startDiscovery() {}
  @override
  void stopDiscovery() {}
  @override
  Stream<IList<CastDevice>> devices() =>
      const Stream<IList<CastDevice>>.empty();
  @override
  Future<void> play() async {}
  @override
  Future<void> pause() async {}
  @override
  Future<void> seek(Duration position) async {}
}

PlaybackQueue _movie(String id) => PlaybackQueue.single(
      PlaybackRequest(
        contentId: id,
        kind: PlaybackKind.movie,
        title: id,
        url: "https://example.test/$id.mp4",
      ),
    );

const CastDevice _kTv = CastDevice(id: "tv", name: "TV");

/// Lets every already-resolved future run.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _FakeCastRepo cast;
  late List<_FakeEngine> built;
  late List<_FakeEngine> script;
  late ProviderContainer container;
  late PlaybackController controller;

  setUp(() {
    cast = _FakeCastRepo();
    built = <_FakeEngine>[];
    script = <_FakeEngine>[];
    GetIt.instance.registerSingleton<ICastRepository>(cast);
    // Engines come from [script] first, then default ones.
    debugPlaybackEngineFactory = () {
      final _FakeEngine engine =
          script.isNotEmpty ? script.removeAt(0) : _FakeEngine();
      built.add(engine);
      return engine;
    };
    container = ProviderContainer();
    controller = container.read(playbackControllerProvider.notifier);
  });

  tearDown(() async {
    container.dispose();
    debugPlaybackEngineFactory = null;
    await GetIt.instance.reset();
  });

  PlayerUiState state() => container.read(playbackControllerProvider);

  test("a swap superseded by a cast that fails leaves a working engine",
      () async {
    final Completer<void> gate = Completer<void>();
    script.add(_FakeEngine(disposeGate: gate));
    controller.start(_movie("a"));
    await _settle();
    expect(built, hasLength(1));

    // Swap parks on the old engine's dispose, then a Cast tap lands.
    final Future<void> swap = controller.debugSwapEngine();
    await _settle();
    final Future<void> casting = controller.castTo(_kTv);
    gate.complete();
    await _settle();
    expect(cast.loads, hasLength(1));
    // The receiver is unreachable.
    cast.loads.single.complete(left(const Failures.streamUnavailable()));
    await Future.wait(<Future<void>>[swap, casting]);
    await _settle();

    expect(state().castDevice, isNull);
    expect(controller.hasVideo, isTrue, reason: "an engine must exist");
    expect(built, hasLength(2));
    controller.playOrPause();
    expect(built.last.playOrPauseCalls, 1);
  });

  test("a cast load that lands after start(B) is ended, not applied", () async {
    controller.start(_movie("a"));
    await _settle();
    final Future<void> casting = controller.castTo(_kTv);
    await _settle();
    expect(cast.loads, hasLength(1));

    controller.start(_movie("b"));
    cast.loads.single.complete(right(unit));
    await casting;
    await _settle();

    expect(state().castDevice, isNull);
    expect(cast.endSessionCalls, 1);
    expect(built.single.opened.last, endsWith("/b.mp4"));
    expect(state().playing, isFalse, reason: "no remote playing flag");
  });
}
