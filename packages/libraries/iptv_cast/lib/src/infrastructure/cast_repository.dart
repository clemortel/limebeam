import "dart:developer" as developer;
import "dart:io" show Platform;

import "package:dartz/dartz.dart" hide IList, IMap, ISet;
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter_chrome_cast/flutter_chrome_cast.dart";
import "package:injectable/injectable.dart";
import "package:iptv_core/iptv_core.dart";

import "../models/cast_device.dart";

/// Data layer for Chromecast handoff. Wraps the native Google Cast SDK
/// (`flutter_chrome_cast`) and exposes only primitive / domain types — no
/// `GoogleCast*` type ever leaves this file, mirroring the media_kit boundary
/// in `iptv_player`. Returns `Either<Failures, T>`; never throws upward.
abstract interface class ICastRepository {
  /// Idempotent. Configures the Cast context for the Default Media Receiver
  /// (`CC1AD845`). Safe to call before any discovery / session.
  Future<void> initialize();

  /// Begins scanning the local network for Chromecast receivers.
  void startDiscovery();

  /// Stops scanning (call when the device picker closes).
  void stopDiscovery();

  /// Discovered Chromecast receivers, updated live while discovery is running.
  Stream<IList<CastDevice>> devices();

  /// Emits true while a remote session is connected, false once it ends.
  Stream<bool> connection();

  /// The remote playhead reported by the receiver (zero with no session).
  Duration get position;

  /// Connects to [device], then loads the stream and starts remote playback
  /// at [startAt]. Returns [Failures.castConnectionFailed] on any error.
  Future<Either<Failures, Unit>> connectAndLoad(
    CastDevice device, {
    required String url,
    required String title,
    required String contentType,
    required Duration startAt,
    required bool isLive,
    String? subtitle,
    String? posterUrl,
  });

  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// Ends the session and stops casting, returning the last known remote
  /// position so local playback can resume exactly where the TV left off.
  Future<Duration> endSession();
}

@LazySingleton(as: ICastRepository)
class CastRepository implements ICastRepository {
  bool _initialized = false;

  /// Last discovered raw devices, keyed by id — the SDK needs the native
  /// object (not just an id) to open a session.
  final Map<String, GoogleCastDevice> _rawById = <String, GoogleCastDevice>{};

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    const String appId = GoogleCastDiscoveryCriteria.kDefaultApplicationId;
    final GoogleCastOptions options = Platform.isIOS
        ? IOSGoogleCastOptions(
            GoogleCastDiscoveryCriteriaInitialize.initWithApplicationID(appId),
            stopCastingOnAppTerminated: true,
          )
        : GoogleCastOptionsAndroid(
            appId: appId,
            stopCastingOnAppTerminated: true,
          );
    await GoogleCastContext.instance.setSharedInstanceWithOptions(options);
    _initialized = true;
  }

  @override
  void startDiscovery() =>
      GoogleCastDiscoveryManager.instance.startDiscovery();

  @override
  void stopDiscovery() =>
      GoogleCastDiscoveryManager.instance.stopDiscovery();

  @override
  Stream<IList<CastDevice>> devices() {
    return GoogleCastDiscoveryManager.instance.devicesStream.map(
      (List<GoogleCastDevice> raw) {
        _rawById
          ..clear()
          ..addEntries(
            raw.map(
              (GoogleCastDevice d) =>
                  MapEntry<String, GoogleCastDevice>(d.deviceID, d),
            ),
          );
        return raw
            .map(
              (GoogleCastDevice d) => CastDevice(
                id: d.deviceID,
                name: d.friendlyName,
              ),
            )
            .toIList();
      },
    );
  }

  @override
  Stream<bool> connection() => GoogleCastSessionManager
      .instance.currentSessionStream
      .map((GoogleCastSession? session) => session != null);

  @override
  Duration get position =>
      GoogleCastRemoteMediaClient.instance.playerPosition;

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
  }) async {
    try {
      final GoogleCastDevice? raw = _rawById[device.id];
      if (raw == null) return left(const Failures.castUnavailable());
      await GoogleCastSessionManager.instance.startSessionWithDevice(raw);
      await GoogleCastRemoteMediaClient.instance.loadMedia(
        GoogleCastMediaInformation(
          contentId: url,
          streamType: isLive
              ? CastMediaStreamType.live
              : CastMediaStreamType.buffered,
          contentUrl: Uri.parse(url),
          contentType: contentType,
          metadata: GoogleCastMovieMediaMetadata(
            title: title,
            subtitle: subtitle,
            images: _images(posterUrl),
          ),
        ),
        autoPlay: true,
        playPosition: startAt,
      );
      return right(unit);
    } catch (error, stackTrace) {
      // Cast errors are surfaced as a dedicated failure rather than the
      // generic transport mapping in [catchError].
      developer.log(
        "cast connect/load failed (${error.runtimeType}: $error)",
        name: "iptv.cast",
        error: error,
        stackTrace: stackTrace,
      );
      return left(const Failures.castConnectionFailed());
    }
  }

  @override
  Future<void> play() => GoogleCastRemoteMediaClient.instance.play();

  @override
  Future<void> pause() => GoogleCastRemoteMediaClient.instance.pause();

  @override
  Future<void> seek(Duration position) => GoogleCastRemoteMediaClient.instance
      .seek(GoogleCastMediaSeekOption(position: position));

  @override
  Future<Duration> endSession() async {
    final Duration last = GoogleCastRemoteMediaClient.instance.playerPosition;
    await GoogleCastSessionManager.instance.endSessionAndStopCasting();
    return last;
  }

  /// Builds the optional poster image list for the receiver's now-playing card.
  List<GoogleCastImage> _images(String? posterUrl) {
    if (posterUrl == null || posterUrl.isEmpty) {
      return const <GoogleCastImage>[];
    }
    return <GoogleCastImage>[GoogleCastImage(url: Uri.parse(posterUrl))];
  }
}
