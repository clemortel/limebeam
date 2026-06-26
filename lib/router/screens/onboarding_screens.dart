import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_auth/iptv_auth.dart";

import "../router.gr.dart";

/// Bienvenue (§4.1.1).
@RoutePage()
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WelcomeView(
      onAddSource: () {
        ref.read(addXtreamSourceNotifierProvider.notifier).reset();
        context.pushRoute(const SourceTypeRoute());
      },
      onHaveSource: () => context.pushRoute(const SourceTypeRoute()),
      onTryDemo: () {
        ref.read(addM3uSourceNotifierProvider.notifier).reset();
        context.pushRoute(ConnectingRoute(kind: SourceType.demo));
      },
    );
  }
}

/// Type selection (§4.1.2).
@RoutePage()
class SourceTypeScreen extends ConsumerWidget {
  const SourceTypeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SourceTypeView(
      onXtream: () {
        ref.read(addXtreamSourceNotifierProvider.notifier).reset();
        context.pushRoute(const XtreamFormRoute());
      },
      onM3u: () {
        ref.read(addM3uSourceNotifierProvider.notifier).reset();
        context.pushRoute(const M3uFormRoute());
      },
    );
  }
}

/// Xtream form (§4.1.4).
@RoutePage()
class XtreamFormScreen extends StatelessWidget {
  const XtreamFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return XtreamFormView(
      onContinue: () => context.pushRoute(const SourceSummaryRoute()),
    );
  }
}

/// M3U form — goes straight to the connecting screen (no summary).
@RoutePage()
class M3uFormScreen extends StatelessWidget {
  const M3uFormScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return M3uFormView(
      onContinue: () =>
          context.pushRoute(ConnectingRoute(kind: SourceType.m3u)),
    );
  }
}

/// Résumé (§4.1.5).
@RoutePage()
class SourceSummaryScreen extends StatelessWidget {
  const SourceSummaryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SourceSummaryView(
      onEdit: () => context.maybePop(),
      onValidate: () => context.pushRoute(ConnectingRoute()),
    );
  }
}
