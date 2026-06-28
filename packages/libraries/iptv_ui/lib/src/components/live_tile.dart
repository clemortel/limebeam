import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";
import "app_badge.dart";
import "pressable_scale.dart";

const double _kTileWidth = 260;
const double _kTileAspect = 16 / 9;

/// Home "Live maintenant" tile (§2.6): 16:9 thumbnail, LIVE badge, name on a
/// bottom scrim.
class LiveTile extends StatelessWidget {
  const LiveTile({
    required this.channelName,
    required this.thumbnailUrl,
    required this.onTap,
    this.width = _kTileWidth,
    super.key,
  });

  final String channelName;
  final String? thumbnailUrl;
  final VoidCallback onTap;
  final double width;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // RepaintBoundary isolates each tile's layer for smoother rail scrolling.
    return RepaintBoundary(
      child: PressableScale(
        onTap: onTap,
        child: SizedBox(
          width: width,
          child: AspectRatio(
            aspectRatio: _kTileAspect,
            child: ClipRRect(
              borderRadius: t.radius.mdAll,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  if (thumbnailUrl != null && thumbnailUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: thumbnailUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth:
                          (width * MediaQuery.devicePixelRatioOf(context))
                              .round(),
                    )
                  else
                    ColoredBox(color: t.colors.bgElevated),
                  const _BottomScrim(),
                  Positioned(
                    top: t.space.x2,
                    left: t.space.x2,
                    child: const AppBadge.live(),
                  ),
                  Positioned(
                    left: t.space.x3,
                    right: t.space.x3,
                    bottom: t.space.x2,
                    child: Text(
                      channelName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.bodyStrong.copyWith(
                        color: t.colors.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomScrim extends StatelessWidget {
  const _BottomScrim();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.center,
          colors: <Color>[Color(0xCC000000), Color(0x00000000)],
        ),
      ),
    );
  }
}
