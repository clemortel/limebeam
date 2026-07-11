import "dart:async";

import "package:flutter/foundation.dart";
import "package:flutter/widgets.dart";
import "package:media_kit/media_kit.dart";
import "package:media_kit_video/media_kit_video.dart";

import "../player_init.dart";

/// A small, muted, best-effort live video preview for the TV channel browser.
///
/// Deliberately a **separate** media_kit [Player] from the full-screen engine
/// (which is the native SurfaceView ExoPlayer on TV): the preview renders a
/// small texture, so its GPU cost is low, and using its own player means the
/// preview and the full-screen player never contend for the single shared
/// native ExoPlayer instance. Pass a null [url] to show nothing (idle).
class LivePreview extends StatefulWidget {
  const LivePreview({required this.url, super.key});

  /// Stream URL to preview, or null to render an empty (idle) preview.
  final String? url;

  @override
  State<LivePreview> createState() => _LivePreviewState();
}

class _LivePreviewState extends State<LivePreview> {
  late final Player _player;
  late final VideoController _controller;

  @override
  void initState() {
    super.initState();
    // Small buffer + fast-start tuning: a preview must appear quickly and must
    // not hoard memory next to the main player on a 1.5 GB Fire TV.
    _player = Player(
      configuration: const PlayerConfiguration(
        logLevel: MPVLogLevel.error,
        bufferSize: 8 * 1024 * 1024,
        muted: true,
      ),
    );
    _controller = VideoController(
      _player,
      configuration: VideoControllerConfiguration(
        enableHardwareAcceleration: !playerSoftwareRenderingOnly,
      ),
    );
    if (defaultTargetPlatform == TargetPlatform.android &&
        !playerSoftwareRenderingOnly) {
      unawaited(_applyAndroidProperties());
    }
    unawaited(_player.setVolume(0));
    _sync();
  }

  @override
  void didUpdateWidget(LivePreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) _sync();
  }

  /// Opens the current URL (autoplay) or stops when there is nothing to show.
  void _sync() {
    final String? url = widget.url;
    if (url == null || url.isEmpty) {
      unawaited(_player.stop());
      return;
    }
    unawaited(_player.open(Media(url)));
  }

  Future<void> _applyAndroidProperties() async {
    final Object platform = _player.platform as Object;
    if (platform is! NativePlayer) return;
    // Fast start + quick abandonment so previews feel responsive and a dead
    // stream doesn't hang the little window.
    await platform.setProperty("cache-pause-initial", "no");
    await platform.setProperty("network-timeout", "8");
    await platform.setProperty("demuxer-max-bytes", "8MiB");
    await platform.setProperty("demuxer-readahead-secs", "2");
    await platform.setProperty(
      "user-agent",
      "Mozilla/5.0 (Linux; Android 11) AppleWebKit/537.36"
          " (KHTML, like Gecko) Chrome/120.0 Mobile Safari/537.36",
    );
  }

  @override
  void dispose() {
    unawaited(_player.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Video(
        controller: _controller,
        controls: null,
        fit: BoxFit.cover,
      ),
    );
  }
}
