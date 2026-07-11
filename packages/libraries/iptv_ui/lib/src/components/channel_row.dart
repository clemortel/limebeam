import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart" show Icons;
import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";
import "app_badge.dart";
import "pressable_scale.dart";

const double _kLogoSize = 48;
const double _kProgressHeight = 2;

/// Live channel list row (§2.5). Primitive-only: logo URL, name, now-playing
/// title, progress fraction, live + favorite flags, callbacks.
class ChannelRow extends StatelessWidget {
  const ChannelRow({
    required this.name,
    required this.logoUrl,
    required this.onTap,
    this.nowPlaying,
    this.progress,
    this.isLive = false,
    this.isFavorite = false,
    this.autofocus = false,
    this.onToggleFavorite,
    this.onFocusChange,
    super.key,
  });

  final String name;
  final String? logoUrl;
  final VoidCallback onTap;

  /// Notified when D-pad focus enters/leaves the row (TV live preview dwell).
  final ValueChanged<bool>? onFocusChange;

  /// Current programme title; null shows "Programme indisponible".
  final String? nowPlaying;

  /// 0..1 elapsed fraction of the current programme.
  final double? progress;
  final bool isLive;
  final bool isFavorite;
  final bool autofocus;
  final VoidCallback? onToggleFavorite;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // RepaintBoundary isolates each row's layer for smoother list scrolling.
    return RepaintBoundary(
      child: PressableScale(
        onTap: onTap,
        autofocus: autofocus,
        onFocusChange: onFocusChange,
        child: Container(
          color: t.colors.bgSurface,
          padding: EdgeInsets.symmetric(
            horizontal: t.space.x4,
            vertical: t.space.x3,
          ),
          child: Row(
            children: <Widget>[
              _Logo(url: logoUrl),
              SizedBox(width: t.space.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style:
                          t.typography.h3.copyWith(color: t.colors.textPrimary),
                    ),
                    SizedBox(height: t.space.x1),
                    Text(
                      nowPlaying ?? "Programme indisponible",
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.typography.caption.copyWith(
                        color: nowPlaying == null
                            ? t.colors.textTertiary
                            : t.colors.textSecondary,
                      ),
                    ),
                    if (progress != null) ...<Widget>[
                      SizedBox(height: t.space.x1),
                      _ProgressLine(fraction: progress!),
                    ],
                  ],
                ),
              ),
              SizedBox(width: t.space.x3),
              if (onToggleFavorite != null)
                PressableScale(
                  onTap: onToggleFavorite,
                  child: Icon(
                    isFavorite ? Icons.star : Icons.star_border,
                    size: 22,
                    color: isFavorite ? t.colors.accent : t.colors.textTertiary,
                  ),
                ),
              if (isLive) ...<Widget>[
                SizedBox(width: t.space.x2),
                const LiveDot(),
              ],
              SizedBox(width: t.space.x2),
              Icon(Icons.chevron_right, color: t.colors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      width: _kLogoSize,
      height: _kLogoSize,
      decoration: BoxDecoration(
        color: t.colors.bgElevated,
        borderRadius: t.radius.smAll,
      ),
      clipBehavior: Clip.antiAlias,
      child: url == null || url!.isEmpty
          ? Icon(Icons.tv, color: t.colors.textTertiary, size: 22)
          : CachedNetworkImage(
              imageUrl: url!,
              fit: BoxFit.contain,
              memCacheWidth:
                  (_kLogoSize * MediaQuery.devicePixelRatioOf(context)).round(),
              errorWidget: (BuildContext c, String _, Object __) =>
                  Icon(Icons.tv, color: t.colors.textTertiary, size: 22),
            ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ClipRRect(
      borderRadius: t.radius.fullAll,
      child: Container(
        height: _kProgressHeight,
        color: t.colors.borderSubtle,
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1),
          child: ColoredBox(color: t.colors.accent),
        ),
      ),
    );
  }
}
