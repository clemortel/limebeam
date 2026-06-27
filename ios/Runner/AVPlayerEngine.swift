import AVFoundation
import AVKit
import Flutter
import GCDWebServer
import UIKit

/// User-Agent sent on every request to the IPTV provider. Its anti-leech
/// rejects AVPlayer's default UA; this mimics a tolerated player. Shared by the
/// direct-VOD asset and the HLS proxy. Tune here if 403s persist.
let kUpstreamUserAgent = "VLC/3.0.20 LibVLC/3.0.20"

/// Native AVPlayer engine bridged to the Dart `AvPlayerEngine`.
///
/// Chosen on iOS so AirPlay streams *video* (libmpv/media_kit cannot AirPlay).
/// One shared `AVPlayer` is driven by a method channel and observed for state,
/// which is pushed over an event channel. The platform view binds an
/// `AVPlayerLayer` to the same player. `allowsExternalPlayback` lets the system
/// hand the video off to an Apple TV.
final class AVPlayerEngineController: NSObject, FlutterStreamHandler {
  static let shared = AVPlayerEngineController()

  let player = AVPlayer()

  private var eventSink: FlutterEventSink?
  private var timeObserver: Any?
  private var observations: [NSKeyValueObservation] = []
  private var currentItem: AVPlayerItem?

  /// Keeps the app alive while backgrounded during AirPlay (see [KeepAlivePlayer]).
  private let keepAlive = KeepAlivePlayer()

  override private init() {
    super.init()
    player.allowsExternalPlayback = true
    player.usesExternalPlaybackWhileExternalScreenIsActive = true
    // During AirPlay the audio plays on the TV, so iOS would suspend this app
    // (which kills the on-device HLS proxy the TV depends on). Hold a silent
    // audio assertion while backgrounded to stay alive; release in foreground.
    NotificationCenter.default.addObserver(
      self, selector: #selector(appDidEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(appWillEnterForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil)
    // Resume the cast after a brief audio interruption (e.g. switching to
    // another app) instead of leaving the TV replaced.
    NotificationCenter.default.addObserver(
      self, selector: #selector(handleInterruption(_:)),
      name: AVAudioSession.interruptionNotification, object: nil)
  }

  @objc private func appDidEnterBackground() {
    if currentItem != nil { keepAlive.start() }
  }

  @objc private func appWillEnterForeground() {
    keepAlive.stop()
  }

  @objc private func handleInterruption(_ note: Notification) {
    guard
      let raw = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
      let type = AVAudioSession.InterruptionType(rawValue: raw)
    else { return }
    // On interruption end, reactivate our session and resume so the cast
    // continues on the TV once the other app yields audio focus.
    if type == .ended, currentItem != nil {
      try? AVAudioSession.sharedInstance().setActive(true)
      player.play()
    }
  }

  // MARK: Registration

  static func register(with registrar: FlutterPluginRegistrar) {
    let control = FlutterMethodChannel(
      name: "limebeam/avplayer", binaryMessenger: registrar.messenger())
    control.setMethodCallHandler { call, result in
      shared.handle(call, result: result)
    }
    let events = FlutterEventChannel(
      name: "limebeam/avplayer/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(shared)

    registrar.register(
      AVPlayerViewFactory(), withId: "limebeam/avplayer_view")
  }

  // MARK: Method channel

  private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "open":
      guard
        let args = call.arguments as? [String: Any],
        let urlString = args["url"] as? String,
        let url = URL(string: urlString)
      else {
        result(FlutterError(code: "bad_args", message: "url required", details: nil))
        return
      }
      open(url)
      result(nil)
    case "play":
      player.play()
      result(nil)
    case "pause":
      player.pause()
      result(nil)
    case "playOrPause":
      if player.timeControlStatus == .paused { player.play() } else { player.pause() }
      result(nil)
    case "seek":
      if let args = call.arguments as? [String: Any], let ms = args["ms"] as? Int {
        let time = CMTime(value: CMTimeValue(ms), timescale: 1000)
        player.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
      }
      result(nil)
    case "setVolume":
      if let args = call.arguments as? [String: Any],
        let volume = args["volume"] as? Double {
        player.volume = Float(volume)
      }
      result(nil)
    case "setAudioTrack":
      if let args = call.arguments as? [String: Any], let id = args["id"] as? String {
        selectTrack(id: id, characteristic: .audible)
      }
      result(nil)
    case "setSubtitleTrack":
      if let args = call.arguments as? [String: Any], let id = args["id"] as? String {
        selectTrack(id: id, characteristic: .legible)
      }
      result(nil)
    case "setSubtitleDelay", "setAudioDelay":
      // AVPlayer has no first-class per-track sync offset. Accepted for
      // contract parity; the Dart side hides the controls (supportsSyncOffsets
      // is false), so this is reached only defensively.
      result(nil)
    case "applySubtitleStyle":
      if let args = call.arguments as? [String: Any] {
        applySubtitleStyle(args)
      }
      result(nil)
    case "dispose":
      dispose()
      result(nil)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  // MARK: Playback

  private func open(_ url: URL) {
    configureAudioSession()
    teardownItemObservers()

    // Everything goes through the on-device LAN proxy so the Apple TV only ever
    // fetches a private-LAN cleartext URL (the receiver's ATS refuses the
    // provider's *public* cleartext edge), and the iPhone handles the provider's
    // redirect/token.
    if url.pathExtension.lowercased() == "m3u8" {
      // Already HLS (live): rewrite playlists through the proxy.
      startItem(AVPlayerItem(url: HlsProxyServer.shared.proxyURL(for: url) ?? url))
      return
    }
    // A "VOD file" from this provider may be a real MP4 *or* raw MPEG-TS
    // mislabeled .mp4 (which AVPlayer can't decode). Probe the first bytes: TS
    // is wrapped in an on-device HLS playlist (so AVPlayer plays it natively and
    // can AirPlay); a real MP4 is served directly via the byte-range proxy.
    HlsProxyServer.shared.vodPlaybackURL(for: url) { [weak self] playURL in
      self?.startItem(AVPlayerItem(url: playURL))
    }
  }

  /// Installs [item] as the current item and begins playback. Main-thread only.
  private func startItem(_ item: AVPlayerItem) {
    currentItem = item
    observeItem(item)
    player.replaceCurrentItem(with: item)
    player.play()
    installTimeObserver()
  }

  private func configureAudioSession() {
    let session = AVAudioSession.sharedInstance()
    // `.longFormVideo` route-sharing policy marks this as a video app for
    // AirPlay routing, so the cast is treated as long-form video and casual
    // app sounds are less likely to hijack the AirPlay route.
    try? session.setCategory(.playback, mode: .moviePlayback, policy: .longFormVideo)
    try? session.setActive(true)
  }

  // MARK: Observation

  private func installTimeObserver() {
    if timeObserver == nil {
      let interval = CMTime(seconds: 0.5, preferredTimescale: 1000)
      timeObserver = player.addPeriodicTimeObserver(
        forInterval: interval, queue: .main
      ) { [weak self] time in
        guard let self = self else { return }
        self.emit(["event": "position", "value": time.seconds * 1000])
        self.emitBuffer()
      }
    }
    observations.append(
      player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
        guard let self = self else { return }
        switch player.timeControlStatus {
        case .playing:
          self.emit(["event": "playing", "value": true])
          self.emit(["event": "buffering", "value": false])
        case .paused:
          self.emit(["event": "playing", "value": false])
        case .waitingToPlayAtSpecifiedRate:
          self.emit(["event": "buffering", "value": true])
        @unknown default:
          break
        }
      })
  }

  private func observeItem(_ item: AVPlayerItem) {
    observations.append(
      item.observe(\.status, options: [.new]) { [weak self] item, _ in
        guard let self = self else { return }
        if item.status == .failed {
          let message = item.error?.localizedDescription ?? "Playback error"
          self.emit(["event": "error", "message": message])
        } else if item.status == .readyToPlay {
          let ms = item.duration.isNumeric ? item.duration.seconds * 1000 : 0
          self.emit(["event": "duration", "value": ms])
          self.emitTracks()
        }
      })
    observations.append(
      item.observe(\.duration, options: [.new]) { [weak self] item, _ in
        guard let self = self, item.duration.isNumeric else { return }
        self.emit(["event": "duration", "value": item.duration.seconds * 1000])
      })
    observations.append(
      item.observe(\.isPlaybackBufferEmpty, options: [.new]) { [weak self] item, _ in
        if item.isPlaybackBufferEmpty {
          self?.emit(["event": "buffering", "value": true])
        }
      })
    observations.append(
      item.observe(\.isPlaybackLikelyToKeepUp, options: [.new]) { [weak self] item, _ in
        if item.isPlaybackLikelyToKeepUp {
          self?.emit(["event": "buffering", "value": false])
        }
      })

    NotificationCenter.default.addObserver(
      self, selector: #selector(onCompleted),
      name: .AVPlayerItemDidPlayToEndTime, object: item)
    NotificationCenter.default.addObserver(
      self, selector: #selector(onFailed),
      name: .AVPlayerItemFailedToPlayToEndTime, object: item)
  }

  @objc private func onCompleted() {
    emit(["event": "completed"])
  }

  @objc private func onFailed(_ note: Notification) {
    let error = note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error
    emit(["event": "error", "message": error?.localizedDescription ?? "Playback error"])
  }

  private func emitBuffer() {
    guard let ranges = currentItem?.loadedTimeRanges, let first = ranges.first else {
      return
    }
    let range = first.timeRangeValue
    let buffered = (range.start.seconds + range.duration.seconds) * 1000
    emit(["event": "buffer", "value": buffered])
  }

  private func emit(_ payload: [String: Any]) {
    eventSink?(payload)
  }

  // MARK: Track selection
  //
  // Uses the modern async `loadMediaSelectionGroup(for:)` (synchronous
  // `AVAsset` property access is deprecated on iOS 16+). All AVFoundation /
  // event-sink work hops to the main actor.

  private func loadGroup(
    _ characteristic: AVMediaCharacteristic
  ) async -> AVMediaSelectionGroup? {
    guard let asset = currentItem?.asset else { return nil }
    return try? await asset.loadMediaSelectionGroup(for: characteristic)
  }

  /// Emits the available audio + subtitle tracks, then the current selection.
  private func emitTracks() {
    Task { @MainActor in
      let audible = await loadGroup(.audible)
      let legible = await loadGroup(.legible)
      emit([
        "event": "tracks",
        "audio": options(of: audible),
        "subtitle": options(of: legible),
      ])
      emitSelection(audible: audible, legible: legible)
    }
  }

  private func options(of group: AVMediaSelectionGroup?) -> [[String: Any]] {
    guard let group = group else { return [] }
    return group.options.enumerated().map { index, option in
      var map: [String: Any] = ["id": "\(index)", "title": option.displayName]
      if let language = option.extendedLanguageTag ?? option.locale?.identifier {
        map["language"] = language
      }
      return map
    }
  }

  /// Emits the indices (as strings) of the currently-selected audio / subtitle
  /// options. A nil legible selection maps to the "no" sentinel (subtitles off).
  @MainActor
  private func emitSelection(
    audible: AVMediaSelectionGroup?, legible: AVMediaSelectionGroup?
  ) {
    guard let item = currentItem else { return }
    let selection = item.currentMediaSelection
    var payload: [String: Any] = ["event": "selectedTracks"]
    if let group = audible,
      let selected = selection.selectedMediaOption(in: group),
      let index = group.options.firstIndex(of: selected) {
      payload["audioId"] = "\(index)"
    }
    if let group = legible {
      if let selected = selection.selectedMediaOption(in: group),
        let index = group.options.firstIndex(of: selected) {
        payload["subtitleId"] = "\(index)"
      } else {
        payload["subtitleId"] = "no"
      }
    }
    emit(payload)
  }

  /// Selects an option by index string, or the "no"/"auto" sentinels.
  private func selectTrack(id: String, characteristic: AVMediaCharacteristic) {
    Task { @MainActor in
      guard let item = currentItem,
        let group = await loadGroup(characteristic)
      else { return }
      switch id {
      case "no":
        item.select(nil, in: group)
      case "auto":
        if let first = group.options.first { item.select(first, in: group) }
      default:
        if let index = Int(id), index >= 0, index < group.options.count {
          item.select(group.options[index], in: group)
        }
      }
      emitSelection(
        audible: characteristic == .audible ? group : await loadGroup(.audible),
        legible: characteristic == .legible ? group : await loadGroup(.legible))
    }
  }

  /// Applies subtitle appearance via an `AVTextStyleRule` on the current item.
  /// Color components are normalized 0..1 ARGB arrays as CoreMedia expects.
  private func applySubtitleStyle(_ args: [String: Any]) {
    guard let item = currentItem else { return }
    let fontScale = args["fontScale"] as? Double ?? 1.0
    let colorArgb = args["textColorArgb"] as? Int ?? 0xFFFF_FFFF
    let backgroundOpacity = args["backgroundOpacity"] as? Double ?? 0.0

    var attributes: [String: Any] = [
      // RelativeFontSize is a percentage of the default subtitle size.
      kCMTextMarkupAttribute_RelativeFontSize as String: fontScale * 100.0,
      kCMTextMarkupAttribute_ForegroundColorARGB as String: argbComponents(colorArgb),
    ]
    if backgroundOpacity > 0 {
      let alpha = min(1.0, max(0.0, backgroundOpacity))
      attributes[kCMTextMarkupAttribute_BackgroundColorARGB as String] =
        [alpha, 0.0, 0.0, 0.0]
    }
    if let rule = AVTextStyleRule(textMarkupAttributes: attributes) {
      item.textStyleRules = [rule]
    }
  }

  /// Splits a 0xAARRGGBB int into normalized [alpha, red, green, blue].
  private func argbComponents(_ argb: Int) -> [Double] {
    let a = Double((argb >> 24) & 0xFF) / 255.0
    let r = Double((argb >> 16) & 0xFF) / 255.0
    let g = Double((argb >> 8) & 0xFF) / 255.0
    let b = Double(argb & 0xFF) / 255.0
    return [a, r, g, b]
  }

  // MARK: Teardown

  private func teardownItemObservers() {
    observations.forEach { $0.invalidate() }
    observations.removeAll()
    NotificationCenter.default.removeObserver(self)
  }

  private func dispose() {
    player.pause()
    if let observer = timeObserver {
      player.removeTimeObserver(observer)
      timeObserver = nil
    }
    teardownItemObservers()
    player.replaceCurrentItem(with: nil)
    currentItem = nil
    keepAlive.stop()
    HlsProxyServer.shared.stop()
    try? AVAudioSession.sharedInstance().setActive(false)
  }

  // MARK: FlutterStreamHandler

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    return nil
  }
}

/// Streams whether the current audio-output route is AirPlay, so Dart can swap
/// to the AVPlayer engine (which streams video over AirPlay) and back to libmpv
/// for local playback. Backed by `AVAudioSession` route-change notifications.
final class AirPlayRouteMonitor: NSObject, FlutterStreamHandler {
  static let shared = AirPlayRouteMonitor()

  private var eventSink: FlutterEventSink?

  static func register(with registrar: FlutterPluginRegistrar) {
    let events = FlutterEventChannel(
      name: "limebeam/route/events", binaryMessenger: registrar.messenger())
    events.setStreamHandler(shared)
  }

  func onListen(
    withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink
  ) -> FlutterError? {
    eventSink = events
    NotificationCenter.default.addObserver(
      self, selector: #selector(routeChanged),
      name: AVAudioSession.routeChangeNotification, object: nil)
    emit()  // Push the current route immediately.
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    NotificationCenter.default.removeObserver(
      self, name: AVAudioSession.routeChangeNotification, object: nil)
    eventSink = nil
    return nil
  }

  @objc private func routeChanged(_ note: Notification) { emit() }

  private func emit() {
    let outputs = AVAudioSession.sharedInstance().currentRoute.outputs
    let airplay = outputs.contains { $0.portType == .airPlay }
    eventSink?(["airplay": airplay])
  }
}

/// Platform-view factory for the AVPlayer surface (`limebeam/avplayer_view`).
final class AVPlayerViewFactory: NSObject, FlutterPlatformViewFactory {
  func create(
    withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
  ) -> FlutterPlatformView {
    return AVPlayerPlatformView(frame: frame)
  }

  func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
    return FlutterStandardMessageCodec.sharedInstance()
  }
}

/// A `UIView` whose backing layer is an `AVPlayerLayer` bound to the shared
/// player, so it resizes automatically with the Flutter view.
final class PlayerLayerView: UIView {
  override class var layerClass: AnyClass { AVPlayerLayer.self }
  var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
}

final class AVPlayerPlatformView: NSObject, FlutterPlatformView {
  private let playerView: PlayerLayerView

  init(frame: CGRect) {
    playerView = PlayerLayerView(frame: frame)
    playerView.playerLayer.player = AVPlayerEngineController.shared.player
    playerView.playerLayer.videoGravity = .resizeAspect
    playerView.backgroundColor = .black
    super.init()
    NotificationCenter.default.addObserver(
      self, selector: #selector(didEnterBackground),
      name: UIApplication.didEnterBackgroundNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(willEnterForeground),
      name: UIApplication.willEnterForegroundNotification, object: nil)
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }

  // A player attached to an AVPlayerLayer is paused by iOS when the app
  // backgrounds — which deactivates the audio session, lets the system suspend
  // the process, and kills the on-device HLS proxy feeding the Apple TV.
  // Detaching the layer in the background keeps audio / AirPlay (and the proxy)
  // alive; re-attaching on foreground restores the local picture.
  @objc private func didEnterBackground() {
    playerView.playerLayer.player = nil
  }

  @objc private func willEnterForeground() {
    playerView.playerLayer.player = AVPlayerEngineController.shared.player
  }

  func view() -> UIView { playerView }
}

/// On-device HLS reverse proxy (GCDWebServer). AVPlayer — locally or on the
/// Apple TV over AirPlay — fetches HLS from this proxy on the device's LAN IP;
/// the proxy fetches the real stream from the IPTV server with a User-Agent its
/// anti-leech accepts (it refuses AVPlayer's own requests), follows the token
/// redirect, and rewrites every playlist URI to come back through the proxy.
///
/// Why LAN-bound (not localhost): in AVPlayer's AirPlay "video" mode the Apple
/// TV fetches the URL itself, so it must be able to reach this server.
final class HlsProxyServer {
  static let shared = HlsProxyServer()

  /// User-Agent sent upstream (shared with the direct-VOD path).
  private let upstreamUserAgent = kUpstreamUserAgent

  private let port: UInt = 8099
  private let server = GCDWebServer()
  private let session = URLSession(configuration: .ephemeral)

  // The origin `.m3u8` re-issues a fresh token/session on every request, so
  // re-fetching it each refresh yields a non-advancing live window (playback
  // stalls). Instead we resolve the origin once to its post-redirect media
  // playlist URL and re-fetch *that* (a real HLS client does the same), so the
  // live window advances. Re-resolve only when the cached URL stops working.
  private let stateQueue = DispatchQueue(label: "limebeam.hlsproxy.state")
  private var activeOrigin: URL?
  private var resolvedPlaylist: URL?
  // Total byte size per VOD origin, learned from a Content-Range total. Used to
  // rewrite suffix ranges (`bytes=-N`) into explicit ones, which this provider's
  // edge mishandles (it returns a malformed Content-Range for suffix requests).
  private var vodTotalSize: [String: Int64] = [:]
  // Estimated TS duration (seconds) per VOD origin, so every playlist request
  // returns an identical playlist (the probe is deterministic but cached to
  // avoid re-fetching the head each time).
  private var vodDuration: [String: Double] = [:]

  private init() { addHandlers() }

  /// Starts the server if needed and returns a proxy playlist URL for [origin],
  /// or nil if the server could not start.
  func proxyURL(for origin: URL) -> URL? {
    startIfNeeded()
    stateQueue.sync {
      activeOrigin = origin
      resolvedPlaylist = nil
    }
    return segmentURL(for: origin, path: "index.m3u8")
  }

  /// Proxy URL for a progressive (VOD) file. The path keeps the real filename
  /// + extension (e.g. `/vod/1451659.mp4`) so AVPlayer/AirPlay recognize the
  /// container from the URL — an extensionless `/vod?u=…` makes AVPlayer
  /// mis-parse the asset ("Cannot Open"). The /vod handler forwards byte ranges
  /// to the edge, so seeking works while only this private-LAN server is hit.
  func vodProxyURL(for origin: URL) -> URL? {
    startIfNeeded()
    let name = origin.lastPathComponent.isEmpty ? "media.mp4" : origin.lastPathComponent
    return proxyFileURL(path: "vod", name: name, origin: origin)
  }

  /// Decides how to play a "VOD file": probes the first bytes. Raw MPEG-TS
  /// (sync byte 0x47, no `ftyp`) is wrapped in an on-device HLS playlist —
  /// AVPlayer can't decode bare TS, but it plays it fine as HLS segments and can
  /// AirPlay that. A real MP4 is served directly through the byte-range proxy.
  func vodPlaybackURL(for origin: URL, completion: @escaping (URL) -> Void) {
    startIfNeeded()
    probeIsTransportStream(origin) { [weak self] isTS in
      guard let self = self else { completion(origin); return }
      let url = isTS ? self.tsHlsURL(for: origin) : self.vodProxyURL(for: origin)
      DispatchQueue.main.async { completion(url ?? origin) }
    }
  }

  private func probeIsTransportStream(
    _ origin: URL, completion: @escaping (Bool) -> Void
  ) {
    var request = URLRequest(url: origin)
    request.setValue(upstreamUserAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("bytes=0-7", forHTTPHeaderField: "Range")
    request.timeoutInterval = 15
    session.dataTask(with: request) { data, _, _ in
      // MP4/MOV begins with a size + 'ftyp' box; raw MPEG-TS begins with 0x47.
      let isTS = data?.first == 0x47
      completion(isTS)
    }.resume()
  }

  /// Playlist URL for a raw-TS "VOD file" wrapped as on-device HLS.
  func tsHlsURL(for origin: URL) -> URL? {
    let stem = origin.deletingPathExtension().lastPathComponent
    let name = (stem.isEmpty ? "media" : stem) + ".m3u8"
    return proxyFileURL(path: "vodts", name: name, origin: origin)
  }

  /// Segment URL used inside the TS-HLS playlist — a `.ts` path so the byte-range
  /// proxy serves it with a `video/mp2t` content type.
  private func tsSegmentURL(for origin: URL) -> URL? {
    let stem = origin.deletingPathExtension().lastPathComponent
    let name = (stem.isEmpty ? "media" : stem) + ".ts"
    return proxyFileURL(path: "vod", name: name, origin: origin)
  }

  private func proxyFileURL(path: String, name: String, origin: URL) -> URL? {
    guard let base = server.serverURL else { return nil }
    guard
      var comps = URLComponents(
        url: base.appendingPathComponent(path).appendingPathComponent(name),
        resolvingAgainstBaseURL: false)
    else { return nil }
    comps.queryItems = [URLQueryItem(name: "u", value: origin.absoluteString)]
    return comps.url
  }

  func stop() {
    if server.isRunning { server.stop() }
    stateQueue.sync {
      activeOrigin = nil
      resolvedPlaylist = nil
      vodTotalSize.removeAll()
      vodDuration.removeAll()
    }
  }

  // MARK: Server lifecycle

  private func startIfNeeded() {
    guard !server.isRunning else { return }
    // Quiet GCDWebServer's own per-connection logging (warnings/errors only).
    GCDWebServer.setLogLevel(3)
    do {
      try server.start(options: [
        GCDWebServerOption_Port: port,
        GCDWebServerOption_BindToLocalhost: false,  // reachable by the Apple TV
        GCDWebServerOption_AutomaticallySuspendInBackground: false,
      ])
    } catch {
      NSLog("HlsProxy failed to start: \(error)")
    }
  }

  private func addHandlers() {
    // Playlist (master or media): fetch upstream, rewrite all URIs.
    server.addHandler(
      forMethod: "GET", path: "/index.m3u8", request: GCDWebServerRequest.self,
      asyncProcessBlock: { [weak self] request, completion in
        guard let self = self else { completion(nil); return }
        self.handlePlaylist(request, completion)
      })
    // Any sub-resource (segment, key, nested playlist): proxy by absolute URL.
    server.addHandler(
      forMethod: "GET", path: "/seg", request: GCDWebServerRequest.self,
      asyncProcessBlock: { [weak self] request, completion in
        guard let self = self else { completion(nil); return }
        self.handleResource(request, completion)
      })
    // Progressive VOD file: range-forwarding byte proxy. Path-regex so the URL
    // can carry the real filename/extension (e.g. /vod/1451659.mp4).
    server.addHandler(
      forMethod: "GET", pathRegex: "^/vod/", request: GCDWebServerRequest.self,
      asyncProcessBlock: { [weak self] request, completion in
        guard let self = self else { completion(nil); return }
        self.handleVod(request, completion)
      })
    // Raw-TS VOD wrapped as HLS: generates the playlist over the original file.
    server.addHandler(
      forMethod: "GET", pathRegex: "^/vodts/", request: GCDWebServerRequest.self,
      asyncProcessBlock: { [weak self] request, completion in
        guard let self = self else { completion(nil); return }
        self.handleTsHls(request, completion)
      })
  }

  /// Builds an HLS VOD playlist that presents the provider's raw MPEG-TS file to
  /// AVPlayer. Stage 1: a single segment spanning the whole file, with the real
  /// duration from the TS PCR clock — proves AVPlayer/AirPlay can play this TS
  /// via HLS. (Multi-segment + keyframe-aligned EXT-X-BYTERANGE comes next, for
  /// seeking.)
  private func handleTsHls(
    _ request: GCDWebServerRequest,
    _ completion: @escaping GCDWebServerCompletionBlock
  ) {
    guard let raw = request.query?["u"], let origin = URL(string: raw) else {
      completion(error(400)); return
    }
    let key = origin.absoluteString
    fetchTotalSize(origin) { [weak self] total in
      guard let self = self, let total = total, total > 0 else {
        completion(self?.error(502) ?? GCDWebServerResponse()); return
      }
      let serve: (Double) -> Void = { seconds in
        let segment = self.tsSegmentURL(for: origin)?.absoluteString
          ?? origin.absoluteString
        let playlist = self.byteRangePlaylist(
          segment: segment, totalBytes: total, totalDuration: max(seconds, 1))
        completion(
          GCDWebServerDataResponse(
            data: Data(playlist.utf8),
            contentType: "application/vnd.apple.mpegurl"))
      }
      if let cached = self.stateQueue.sync(execute: { self.vodDuration[key] }) {
        serve(cached)
        return
      }
      self.probeDuration(origin, totalSize: total) { duration in
        if let duration = duration, duration > 1 {
          self.stateQueue.sync { self.vodDuration[key] = duration }
        }
        serve(duration ?? 0)
      }
    }
  }

  /// Builds a multi-segment VOD playlist that carves the single TS file into
  /// ~10s `EXT-X-BYTERANGE` chunks of the same resource (188-byte aligned).
  /// Durations are proportional to bytes (assumes roughly constant bitrate);
  /// Stage 2 will keyframe-align and use real per-segment PCR durations.
  private func byteRangePlaylist(
    segment: String, totalBytes: Int64, totalDuration: Double
  ) -> String {
    let targetSeconds = 10.0
    let packet: Int64 = 188
    let byteRate = Double(totalBytes) / totalDuration
    var segSize = Int64((byteRate * targetSeconds).rounded())
    segSize = max((segSize / packet) * packet, packet * 1024)  // 188-aligned, ≥ ~192KB
    var lines = [
      "#EXTM3U",
      "#EXT-X-VERSION:4",
      "#EXT-X-PLAYLIST-TYPE:VOD",
      "#EXT-X-TARGETDURATION:\(Int(targetSeconds.rounded(.up)) + 1)",
      "#EXT-X-MEDIA-SEQUENCE:0",
    ]
    var offset: Int64 = 0
    while offset < totalBytes {
      let length = min(segSize, totalBytes - offset)
      let duration = totalDuration * Double(length) / Double(totalBytes)
      lines.append("#EXTINF:\(String(format: "%.3f", duration)),")
      lines.append("#EXT-X-BYTERANGE:\(length)@\(offset)")
      lines.append(segment)
      offset += length
    }
    lines.append("#EXT-X-ENDLIST")
    return lines.joined(separator: "\n") + "\n"
  }

  /// Estimates the TS duration from the **head only**: it finds the first and
  /// last PCR within one head window plus their byte offsets, derives the
  /// byte-rate, and scales to the whole file. This avoids the unreliable tail
  /// fetch (token/redirect) that intermittently produced a 1 s duration (→ a
  /// single giant segment → stuck). Deterministic, so the playlist is stable.
  private func probeDuration(
    _ origin: URL, totalSize: Int64, attempt: Int = 0,
    completion: @escaping (Double?) -> Void
  ) {
    fetchRange(origin, "bytes=0-4194303") { [weak self] head in  // 4 MB head
      guard let self = self else { completion(nil); return }
      if let head = head, let bounds = self.pcrBounds(in: head),
        bounds.lastPCR > bounds.firstPCR, bounds.lastOffset > bounds.firstOffset {
        let spanSeconds = Double(bounds.lastPCR - bounds.firstPCR) / 90_000.0
        let spanBytes = Double(bounds.lastOffset - bounds.firstOffset)
        let bytesPerSecond = spanBytes / spanSeconds
        let duration = Double(totalSize) / bytesPerSecond
        completion(duration)
        return
      }
      // The edge fetch (token/redirect) is occasionally flaky and returns a
      // non-TS body; retry a few times before giving up so we never fall back
      // to a single giant segment.
      if attempt < 3 {
        NSLog("HlsProxy duration: PCR bounds not found, retry \(attempt + 1)")
        self.probeDuration(
          origin, totalSize: totalSize, attempt: attempt + 1, completion: completion)
      } else {
        NSLog("HlsProxy duration: PCR bounds not found after retries")
        completion(nil)
      }
    }
  }

  private func fetchRange(
    _ origin: URL, _ range: String, completion: @escaping (Data?) -> Void
  ) {
    var request = URLRequest(url: origin)
    request.setValue(upstreamUserAgent, forHTTPHeaderField: "User-Agent")
    request.setValue(range, forHTTPHeaderField: "Range")
    request.timeoutInterval = 20
    session.dataTask(with: request) { data, _, _ in completion(data) }.resume()
  }

  /// Scans MPEG-TS packets (188 bytes, sync 0x47) for the first and last PCR
  /// values (90 kHz) in [data], with their byte offsets. Resyncs to the packet
  /// grid first.
  private func pcrBounds(
    in data: Data
  ) -> (firstOffset: Int, firstPCR: Int64, lastOffset: Int, lastPCR: Int64)? {
    let bytes = [UInt8](data)
    let count = bytes.count
    guard count >= 188 * 2 else { return nil }
    var grid = -1
    for offset in 0..<188 where offset + 188 * 2 < count {
      if bytes[offset] == 0x47 && bytes[offset + 188] == 0x47
        && bytes[offset + 188 * 2] == 0x47 {
        grid = offset
        break
      }
    }
    guard grid >= 0 else { return nil }
    var first: (Int, Int64)?
    var last: (Int, Int64)?
    var i = grid
    while i + 188 <= count {
      guard bytes[i] == 0x47 else { i += 1; continue }
      let adaptation = (bytes[i + 3] >> 4) & 0x03
      if (adaptation == 2 || adaptation == 3), Int(bytes[i + 4]) >= 7,
        (bytes[i + 5] & 0x10) != 0 {
        let b = i + 6
        let pcr =
          (Int64(bytes[b]) << 25) | (Int64(bytes[b + 1]) << 17)
          | (Int64(bytes[b + 2]) << 9) | (Int64(bytes[b + 3]) << 1)
          | (Int64(bytes[b + 4]) >> 7)
        if first == nil { first = (i, pcr) }
        last = (i, pcr)
      }
      i += 188
    }
    guard let first = first, let last = last else { return nil }
    return (first.0, first.1, last.0, last.1)
  }

  /// Streams a progressive file from the provider's edge, forwarding the
  /// client's Range so the response is a proper 206 with Content-Range /
  /// Content-Length — what AVPlayer needs to seek. The Apple TV fetches this
  /// from the private LAN; the iPhone talks to the public (cleartext) edge.
  private func handleVod(
    _ request: GCDWebServerRequest,
    _ completion: @escaping GCDWebServerCompletionBlock
  ) {
    guard let raw = request.query?["u"], let origin = URL(string: raw) else {
      completion(error(400)); return
    }
    // The content type comes from the proxy request path (.ts → video/mp2t,
    // .mp4 → video/mp4), not the upstream — the provider mislabels TS as .mp4,
    // and AVPlayer must see the right type for an HLS TS segment.
    let localType = contentType(for: URL(fileURLWithPath: request.path))
    // Resolve the client's Range (rewriting suffix ranges to explicit ones),
    // then stream that range from the edge.
    resolveVodRange(origin, request) { [weak self] range in
      guard let self = self else {
        completion(nil)
        return
      }
      var upstream = URLRequest(url: origin)
      upstream.setValue(self.upstreamUserAgent, forHTTPHeaderField: "User-Agent")
      upstream.timeoutInterval = 30
      if let range = range { upstream.setValue(range, forHTTPHeaderField: "Range") }
      let relay = VodRelay()
      relay.onResponse = { http in
        let length = http.expectedContentLength
        let contentRange = http.value(forHTTPHeaderField: "Content-Range")
        if let total = self.totalFromContentRange(contentRange) {
          self.stateQueue.sync { self.vodTotalSize[origin.absoluteString] = total }
        }
        let response = VodStreamResponse(
          relay: relay,
          contentType: localType,
          contentLength: length >= 0 ? UInt(length) : UInt.max,
          statusCode: http.statusCode,
          contentRange: contentRange)
        completion(response)
      }
      relay.onError = { completion(self.error(502)) }
      relay.start(upstream)
    }
  }

  /// Resolves the client's Range into a header to forward. Explicit and
  /// open-ended ranges pass through; **suffix** ranges (`bytes=-N`) are rewritten
  /// to explicit `bytes=(total-N)-(total-1)` because the edge mishandles them
  /// (this is what breaks the mp4 moov fetch and thus AVPlayer/AirPlay).
  private func resolveVodRange(
    _ origin: URL, _ request: GCDWebServerRequest,
    completion: @escaping (String?) -> Void
  ) {
    guard request.hasByteRange() else { completion(nil); return }
    let location = request.byteRange.location
    let length = request.byteRange.length
    let openLocation = location == NSNotFound || UInt(bitPattern: location) == .max
    let openLength = length == NSNotFound || UInt(bitPattern: length) == .max
    if openLocation {
      let suffix = Int64(length)
      fetchTotalSize(origin) { total in
        if let total = total, total > 0 {
          let start = max(0, total - suffix)
          completion("bytes=\(start)-\(total - 1)")
        } else {
          completion("bytes=-\(length)")  // best-effort fallback
        }
      }
      return
    }
    if openLength {
      completion("bytes=\(location)-")
    } else {
      completion("bytes=\(location)-\(location + length - 1)")
    }
  }

  /// Returns the total file size for [origin], from cache or a `bytes=0-0` probe.
  private func fetchTotalSize(_ origin: URL, completion: @escaping (Int64?) -> Void) {
    if let cached = stateQueue.sync(execute: { vodTotalSize[origin.absoluteString] }) {
      completion(cached)
      return
    }
    var request = URLRequest(url: origin)
    request.setValue(upstreamUserAgent, forHTTPHeaderField: "User-Agent")
    request.setValue("bytes=0-0", forHTTPHeaderField: "Range")
    request.timeoutInterval = 15
    session.dataTask(with: request) { [weak self] _, response, _ in
      let total = self?.totalFromContentRange(
        (response as? HTTPURLResponse)?.value(forHTTPHeaderField: "Content-Range"))
      if let self = self, let total = total {
        self.stateQueue.sync { self.vodTotalSize[origin.absoluteString] = total }
      }
      completion(total)
    }.resume()
  }

  /// Parses the total from a `Content-Range: bytes a-b/TOTAL` header.
  private func totalFromContentRange(_ value: String?) -> Int64? {
    guard let value = value, let slash = value.lastIndex(of: "/") else { return nil }
    let total = value[value.index(after: slash)...].trimmingCharacters(
      in: .whitespaces)
    return Int64(total)
  }

  // MARK: Handlers

  private func handlePlaylist(
    _ request: GCDWebServerRequest,
    _ completion: @escaping GCDWebServerCompletionBlock
  ) {
    guard let raw = request.query?["u"], let origin = URL(string: raw) else {
      completion(error(400)); return
    }
    // Re-use the resolved live-media-playlist URL so the window advances; fall
    // back to the origin (fresh token) only when that cached URL fails.
    let cached: URL? = stateQueue.sync {
      if activeOrigin != origin {
        activeOrigin = origin
        resolvedPlaylist = nil
      }
      return resolvedPlaylist
    }
    let target = cached ?? origin
    fetch(target) { [weak self] data, finalURL, status in
      guard let self = self else { return }
      if status == 200, let text = String(data: data ?? Data(), encoding: .utf8) {
        self.servePlaylist(text, finalURL: finalURL ?? target, completion)
        return
      }
      // Cached URL went stale (token expired / 403): re-resolve from origin.
      if target != origin {
        NSLog("HlsProxy playlist \(status) on cached URL — re-resolving origin")
        self.stateQueue.sync { self.resolvedPlaylist = nil }
        self.fetch(origin) { data2, finalURL2, status2 in
          NSLog("HlsProxy origin re-resolve \(status2): \(origin.absoluteString)")
          guard status2 == 200,
            let text = String(data: data2 ?? Data(), encoding: .utf8)
          else {
            completion(self.error(502)); return
          }
          self.servePlaylist(text, finalURL: finalURL2 ?? origin, completion)
        }
        return
      }
      NSLog("HlsProxy upstream playlist \(status): \(origin.absoluteString)")
      completion(self.error(502))
    }
  }

  /// Caches the resolved playlist URL, rewrites every URI through the proxy,
  /// and completes the response. Logs a one-line summary for diagnostics.
  private func servePlaylist(
    _ text: String, finalURL: URL, _ completion: @escaping GCDWebServerCompletionBlock
  ) {
    if !text.contains("#EXTM3U") {
      // Not an HLS playlist — the provider's `.m3u8` likely just redirects to a
      // raw MPEG-TS stream, which AVPlayer cannot decode.
      NSLog("HlsProxy: upstream is NOT an HLS playlist (first 80): "
        + String(text.prefix(80)))
    } else {
      stateQueue.sync { resolvedPlaylist = finalURL }
    }
    let rewritten = rewritePlaylist(text, base: finalURL)
    completion(
      GCDWebServerDataResponse(
        data: Data(rewritten.utf8),
        contentType: "application/vnd.apple.mpegurl"))
  }

  private func handleResource(
    _ request: GCDWebServerRequest,
    _ completion: @escaping GCDWebServerCompletionBlock
  ) {
    guard let raw = request.query?["u"], let origin = URL(string: raw) else {
      completion(error(400)); return
    }
    // Nested playlists are small and must be rewritten — buffer them.
    if origin.pathExtension.lowercased() == "m3u8" {
      fetch(origin) { [weak self] data, finalURL, status in
        guard let self = self else { return }
        guard let data = data, status == 200,
          let text = String(data: data, encoding: .utf8)
        else {
          completion(self.error(status >= 400 ? status : 502)); return
        }
        let rewritten = self.rewritePlaylist(text, base: finalURL ?? origin)
        completion(
          GCDWebServerDataResponse(
            data: Data(rewritten.utf8),
            contentType: "application/vnd.apple.mpegurl"))
      }
      return
    }
    // Binary segment / key: buffer fully and serve with a Content-Length.
    // AVPlayer aborts chunked, unknown-length segments (observed: it pulls a
    // little then drops the connection → "Broken pipe"), so a complete,
    // length-declared response is what keeps it playing. Latency is hidden by
    // AVPlayer's segment prefetch. Upstream errors are propagated, not served
    // as a (corrupt) segment body.
    fetch(origin) { [weak self] data, _, status in
      guard let self = self else { return }
      guard let data = data, status == 200 else {
        NSLog("HlsProxy segment upstream \(status): \(origin.absoluteString)")
        completion(self.error(status >= 400 ? status : 502)); return
      }
      completion(
        GCDWebServerDataResponse(
          data: data, contentType: self.contentType(for: origin)))
    }
  }

  // MARK: Upstream fetch

  private func fetch(
    _ url: URL, done: @escaping (Data?, URL?, Int) -> Void
  ) {
    var req = URLRequest(url: url)
    req.setValue(upstreamUserAgent, forHTTPHeaderField: "User-Agent")
    req.timeoutInterval = 20
    session.dataTask(with: req) { data, response, _ in
      let status = (response as? HTTPURLResponse)?.statusCode ?? -1
      done(data, response?.url, status)
    }.resume()
  }

  // MARK: Playlist rewriting

  /// Rewrites every URI in an HLS playlist (segment/variant lines and `URI="…"`
  /// attributes) to point back through `/seg?u=<absolute-url>`.
  private func rewritePlaylist(_ text: String, base: URL) -> String {
    var out: [String] = []
    for line in text.components(separatedBy: "\n") {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if trimmed.isEmpty {
        out.append(line)
      } else if trimmed.hasPrefix("#") {
        out.append(rewriteAttribute(line, base: base))
      } else if let abs = URL(string: trimmed, relativeTo: base)?.absoluteString,
        let proxied = segmentURL(forAbsolute: abs) {
        out.append(proxied)
      } else {
        out.append(line)
      }
    }
    return out.joined(separator: "\n")
  }

  /// Rewrites a `URI="…"` attribute (EXT-X-KEY / EXT-X-MEDIA / EXT-X-MAP).
  private func rewriteAttribute(_ line: String, base: URL) -> String {
    guard let start = line.range(of: "URI=\"") else { return line }
    let valueStart = start.upperBound
    guard let valueEnd = line[valueStart...].firstIndex(of: "\"") else { return line }
    let uri = String(line[valueStart..<valueEnd])
    guard let abs = URL(string: uri, relativeTo: base)?.absoluteString,
      let proxied = segmentURL(forAbsolute: abs)
    else { return line }
    return line.replacingCharacters(in: valueStart..<valueEnd, with: proxied)
  }

  // MARK: URL helpers

  private func segmentURL(forAbsolute absolute: String) -> String? {
    guard let url = URL(string: absolute) else { return nil }
    return segmentURL(for: url, path: "seg")?.absoluteString
  }

  private func segmentURL(for origin: URL, path: String) -> URL? {
    guard let base = server.serverURL else { return nil }
    guard
      var comps = URLComponents(
        url: base.appendingPathComponent(path), resolvingAgainstBaseURL: false)
    else { return nil }
    comps.queryItems = [URLQueryItem(name: "u", value: origin.absoluteString)]
    return comps.url
  }

  private func contentType(for url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "ts": return "video/mp2t"
    case "m4s", "mp4": return "video/mp4"
    case "aac": return "audio/aac"
    case "vtt": return "text/vtt"
    default: return "application/octet-stream"
    }
  }

  private func error(_ code: Int) -> GCDWebServerResponse {
    let response = GCDWebServerResponse()
    response.statusCode = code
    return response
  }
}

/// Fetches one progressive (VOD) byte range from the provider's edge and feeds
/// it to a [VodStreamResponse] as it arrives. Captures the upstream response
/// headers first ([onResponse]) so the proxy can mirror the status / Content-
/// Range / Content-Length the Apple TV needs to seek. Pull-based to match
/// GCDWebServer's body reader; lock-guarded across the URLSession + server
/// queues.
final class VodRelay: NSObject, URLSessionDataDelegate, @unchecked Sendable {
  /// Fired once with the upstream HTTP response (headers) before any body.
  var onResponse: ((HTTPURLResponse) -> Void)?
  /// Fired if the upstream fails before any response is delivered.
  var onError: (() -> Void)?

  private let lock = NSLock()
  private var buffer = Data()
  private var finished = false
  private var failure: Error?
  private var pending: ((Data?, Error?) -> Void)?
  private var session: URLSession?
  private var responded = false

  func start(_ request: URLRequest) {
    let session = URLSession(
      configuration: .ephemeral, delegate: self, delegateQueue: nil)
    self.session = session
    session.dataTask(with: request).resume()
  }

  /// Pulls the next body chunk: a data chunk, empty `Data()` at end, or error.
  func next(_ completion: @escaping (Data?, Error?) -> Void) {
    lock.lock()
    if let failure = failure {
      lock.unlock()
      completion(nil, failure)
    } else if !buffer.isEmpty {
      let chunk = buffer
      buffer.removeAll(keepingCapacity: true)
      lock.unlock()
      completion(chunk, nil)
    } else if finished {
      lock.unlock()
      completion(Data(), nil)
    } else {
      pending = completion
      lock.unlock()
    }
  }

  func cancel() {
    session?.invalidateAndCancel()
  }

  // MARK: URLSessionDataDelegate

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask,
    didReceive response: URLResponse,
    completionHandler: @escaping (URLSession.ResponseDisposition) -> Void
  ) {
    responded = true
    if let http = response as? HTTPURLResponse, http.statusCode < 400 {
      onResponse?(http)
      completionHandler(.allow)
    } else {
      let status = (response as? HTTPURLResponse)?.statusCode ?? 502
      NSLog("HlsProxy vod upstream \(status)")
      onError?()
      completionHandler(.cancel)
    }
  }

  func urlSession(
    _ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data
  ) {
    lock.lock()
    if let completion = pending {
      pending = nil
      lock.unlock()
      completion(data, nil)
    } else {
      buffer.append(data)
      lock.unlock()
    }
  }

  func urlSession(
    _ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?
  ) {
    if let error = error, !responded {
      onError?()
    } else if let error = error {
      fail(error)
    } else {
      finish()
    }
    session.finishTasksAndInvalidate()
  }

  private func finish() {
    lock.lock()
    finished = true
    let completion = pending
    pending = nil
    lock.unlock()
    completion?(Data(), nil)
  }

  private func fail(_ error: Error) {
    lock.lock()
    failure = error
    let completion = pending
    pending = nil
    lock.unlock()
    completion?(nil, error)
  }
}

/// A GCDWebServer response whose body streams from a [VodRelay]. Mirrors the
/// upstream status / Content-Range and sets a known Content-Length so the
/// framing is byte-exact (chunked transfer breaks AVPlayer's seeking).
final class VodStreamResponse: GCDWebServerResponse, @unchecked Sendable {
  private let relay: VodRelay

  init(
    relay: VodRelay, contentType: String, contentLength: UInt,
    statusCode: Int, contentRange: String?
  ) {
    self.relay = relay
    super.init()
    self.contentType = contentType
    self.statusCode = statusCode
    self.contentLength = contentLength
    setValue("bytes", forAdditionalHeader: "Accept-Ranges")
    if let contentRange = contentRange {
      setValue(contentRange, forAdditionalHeader: "Content-Range")
    }
  }

  override func asyncReadData(completion: @escaping (Data?, Error?) -> Void) {
    relay.next(completion)
  }

  override func close() {
    relay.cancel()
  }
}

/// Plays a silent, looping audio buffer to hold an active-audio assertion so
/// iOS keeps the app alive in the background. Needed only during AirPlay: the
/// AVPlayer offloads audio to the Apple TV, so iOS sees no local audio and
/// would otherwise suspend the app — killing the on-device HLS proxy the TV is
/// streaming from. Run only while backgrounded to avoid any foreground impact.
final class KeepAlivePlayer {
  private let engine = AVAudioEngine()
  private let node = AVAudioPlayerNode()
  private var running = false

  func start() {
    guard !running,
      let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2),
      let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 44_100)
    else { return }
    buffer.frameLength = buffer.frameCapacity  // zero-filled PCM = silence

    engine.attach(node)
    engine.connect(node, to: engine.mainMixerNode, format: format)
    do {
      try engine.start()
      node.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
      node.play()
      running = true
    } catch {
      NSLog("KeepAlive start failed: \(error)")
    }
  }

  func stop() {
    guard running else { return }
    node.stop()
    engine.stop()
    engine.detach(node)
    running = false
  }
}

