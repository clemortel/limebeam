import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

/// Starts the add flow from a link in the clipboard. A recognised link
/// skips the type picker, the form and the summary; anything else falls back
/// to [fallback] so the user is never stuck.
Future<void> _startFromClipboard(
  BuildContext context,
  WidgetRef ref, {
  required VoidCallback fallback,
  bool toastOnInvalid = false,
}) async {
  final SourceType? type =
      await ref.read(sourceLinkProvider.notifier).applyClipboard();
  if (!context.mounted) return;
  if (type == null) {
    if (toastOnInvalid) {
      AppToast.show(
        context,
        message: AppLocalizations.of(context).onboardingPasteInvalid,
        kind: ToastKind.warning,
      );
    }
    fallback();
    return;
  }
  await context.pushRoute(ConnectingRoute(kind: type));
}

/// Bienvenue (§4.1.1).
@RoutePage()
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return WelcomeView(
      onAddSource: () {
        ref.read(addXtreamSourceProvider.notifier).reset();
        context.pushRoute(const SourceTypeRoute());
      },
      // "I already have a source" means a link is at hand: try the clipboard
      // first, and only then fall back to the type picker.
      onHaveSource: () => _startFromClipboard(
        context,
        ref,
        fallback: () => context.pushRoute(const SourceTypeRoute()),
      ),
      onTryDemo: () {
        ref.read(addM3uSourceProvider.notifier).reset();
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
        ref.read(addXtreamSourceProvider.notifier).reset();
        context.pushRoute(const XtreamFormRoute());
      },
      onM3u: () {
        ref.read(addM3uSourceProvider.notifier).reset();
        context.pushRoute(const M3uFormRoute());
      },
      onPasteLink: () => _startFromClipboard(
        context,
        ref,
        toastOnInvalid: true,
        fallback: () {},
      ),
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
      // Phone-filled + reviewed on TV → skip the summary, connect straight away.
      onPhoneFilled: () => context.pushRoute(ConnectingRoute()),
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
