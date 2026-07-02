import "package:cached_network_image/cached_network_image.dart";
import "package:flutter/material.dart" show Icons;
import "package:flutter/widgets.dart";

import "../responsive/form_factor.dart";
import "../theme/app_theme.dart";
import "app_badge.dart";
import "pressable_scale.dart";
import "skeleton_box.dart";

const double _kProgressBarHeight = 3;
const double _kWatchedOpacity = 0.6;

/// Logical width the poster is decoded at (memory cache cap). TVs render bigger
/// posters but at a low device-pixel-ratio, so a larger logical width keeps
/// them sharp while staying memory-friendly on low-RAM boxes (Firestick).
const double _kPosterDecodeWidth = 220;
const double _kPosterDecodeWidthTv = 320;

/// VOD poster card (§2.4). Primitive-only: takes strings + a resume fraction
/// + callbacks. The 2:3 poster, NEW badge, and resume bar are baked in.
class MediaPosterCard extends StatelessWidget {
  const MediaPosterCard({
    required this.title,
    required this.subtitle,
    required this.posterUrl,
    required this.onTap,
    this.onLongPress,
    this.isNew = false,
    this.watched = false,
    this.resumeFraction,
    this.qualityLabel,
    this.autofocus = false,
    super.key,
  });

  final String title;
  final String subtitle;
  final String? posterUrl;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final bool isNew;
  final bool watched;

  /// 0..1 elapsed fraction; shows the resume bar when non-null.
  final double? resumeFraction;
  final String? qualityLabel;

  /// Anchors the TV remote on this card on first build (set on the first card
  /// of a grid/rail so entering the content pane always lands focus).
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // RepaintBoundary isolates each card's layer so scrolling the grid (incl.
    // under the translucent nav bar) doesn't repaint siblings.
    return RepaintBoundary(
      child: PressableScale(
        onTap: onTap,
        onLongPress: onLongPress,
        autofocus: autofocus,
        focusBorderRadius: t.radius.lgAll,
        // The poster flexes to fill the bounded cell/rail height so the two
        // text lines never cause a RenderFlex overflow (incl. large text scale).
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Expanded(
              child: ClipRRect(
                borderRadius: t.radius.lgAll,
                child: Stack(
                  fit: StackFit.expand,
                  children: <Widget>[
                    _Poster(url: posterUrl, watched: watched),
                    if (isNew)
                      Positioned(
                        top: t.space.x2,
                        left: t.space.x2,
                        child: const AppBadge.isNew(),
                      ),
                    if (qualityLabel != null)
                      Positioned(
                        top: t.space.x2,
                        right: t.space.x2,
                        child: AppBadge(
                          label: qualityLabel!,
                          kind: AppBadgeKind.classification,
                        ),
                      ),
                    if (watched)
                      Center(
                        child: Icon(
                          Icons.check_circle,
                          color: t.colors.textPrimary,
                          size: 32,
                        ),
                      ),
                    if (resumeFraction != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 0,
                        child: _ResumeBar(fraction: resumeFraction!),
                      ),
                  ],
                ),
              ),
            ),
            SizedBox(height: t.space.x2),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: t.typography.h3.copyWith(color: t.colors.textPrimary),
            ),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  t.typography.caption.copyWith(color: t.colors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _Poster extends StatelessWidget {
  const _Poster({required this.url, required this.watched});

  final String? url;
  final bool watched;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final double logicalWidth = FormFactorScope.isTv(context)
        ? _kPosterDecodeWidthTv
        : _kPosterDecodeWidth;
    final int decodeWidth =
        (logicalWidth * MediaQuery.devicePixelRatioOf(context)).round();
    final Widget image = url == null || url!.isEmpty
        ? SkeletonBox(borderRadius: t.radius.lgAll)
        : CachedNetworkImage(
            imageUrl: url!,
            fit: BoxFit.cover,
            memCacheWidth: decodeWidth,
            placeholder: (BuildContext c, String _) =>
                SkeletonBox(borderRadius: t.radius.lgAll),
            errorWidget: (BuildContext c, String _, Object __) =>
                ColoredBox(color: t.colors.bgSurface),
          );
    return Opacity(opacity: watched ? _kWatchedOpacity : 1, child: image);
  }
}

class _ResumeBar extends StatelessWidget {
  const _ResumeBar({required this.fraction});

  final double fraction;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      height: _kProgressBarHeight,
      color: t.colors.borderSubtle,
      child: FractionallySizedBox(
        alignment: Alignment.centerLeft,
        widthFactor: fraction.clamp(0, 1),
        child: ColoredBox(color: t.colors.accent),
      ),
    );
  }
}
