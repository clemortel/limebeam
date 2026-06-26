import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:iptv_player/iptv_player.dart";

/// Full-screen player (§4.5). Renders the app-scoped [PlaybackController]; the
/// queue is set via `start(...)` before this route is pushed, so playback keeps
/// running (mini-player) when it's popped.
@RoutePage()
class PlayerScreen extends StatelessWidget {
  const PlayerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const PlayerView();
  }
}
