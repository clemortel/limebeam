import "package:flutter/material.dart" show Icons;
import "package:flutter/widgets.dart";

import "../theme/app_theme.dart";

const double _kTitleRowHeight = 28;

/// Horizontal section with a title + optional "Voir tout" action (§2.8).
/// Caller supplies the already-built child cards and their height.
class SectionCarousel extends StatelessWidget {
  const SectionCarousel({
    required this.title,
    required this.itemCount,
    required this.itemBuilder,
    required this.itemExtent,
    required this.height,
    this.onSeeAll,
    super.key,
  });

  final String title;
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Width of each card (gap is added between them).
  final double itemExtent;

  /// Height of the scrolling card area.
  final double height;
  final VoidCallback? onSeeAll;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          height: _kTitleRowHeight,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.x4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text(
                  title,
                  style: t.typography.h3.copyWith(color: t.colors.textPrimary),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Row(
                      children: <Widget>[
                        Text(
                          "Voir tout",
                          style: t.typography.caption
                              .copyWith(color: t.colors.textSecondary),
                        ),
                        Icon(
                          Icons.chevron_right,
                          size: 16,
                          color: t.colors.textSecondary,
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
        SizedBox(height: t.space.x2),
        SizedBox(
          height: height,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: t.space.x4),
            itemCount: itemCount,
            separatorBuilder: (BuildContext c, int i) =>
                SizedBox(width: t.space.x3),
            itemBuilder: (BuildContext c, int i) =>
                SizedBox(width: itemExtent, child: itemBuilder(c, i)),
          ),
        ),
      ],
    );
  }
}
