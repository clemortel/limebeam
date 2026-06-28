import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

/// Succès (§4.1.7). Count summary + "Découvrir".
@RoutePage()
class SourceSuccessScreen extends ConsumerWidget {
  const SourceSuccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final SyncProgress p = ref.watch(sourceSyncNotifierProvider);
    final String summary = l.successCounts(p.channels, p.movies, p.series);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (BuildContext context, BoxConstraints constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.all(t.space.x4),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: <Widget>[
                      const Spacer(),
                      Icon(
                        Icons.check_circle,
                        size: 64,
                        color: t.colors.success,
                      ),
                      SizedBox(height: t.space.x6),
                      Text(
                        l.successTitle,
                        style: t.typography.h1
                            .copyWith(color: t.colors.textPrimary),
                      ),
                      SizedBox(height: t.space.x2),
                      Text(
                        summary,
                        textAlign: TextAlign.center,
                        style: t.typography.body
                            .copyWith(color: t.colors.textSecondary),
                      ),
                      if (!p.epgLoaded) ...<Widget>[
                        SizedBox(height: t.space.x2),
                        Text(
                          l.successEpgUnavailable,
                          style: t.typography.caption
                              .copyWith(color: t.colors.warning),
                        ),
                      ],
                      const Spacer(),
                      PrimaryButton(
                        label: l.successDiscover,
                        onPressed: () =>
                            context.router.replaceAll(<PageRouteInfo<dynamic>>[
                          const MainShellRoute(),
                        ]),
                      ),
                      SizedBox(height: t.space.x4),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
