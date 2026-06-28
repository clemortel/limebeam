import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_auth/iptv_auth.dart";
import "package:iptv_core/iptv_core.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_playlist/iptv_playlist.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

/// Loading screen (§4.1.6). Authenticates + persists the source, then runs
/// the eager sync (live, vod, series, epg) with real sub-steps. Handles both
/// Xtream and M3U sources via [kind].
@RoutePage()
class ConnectingScreen extends ConsumerStatefulWidget {
  const ConnectingScreen({this.kind = SourceType.xtream, super.key});

  final SourceType kind;

  @override
  ConsumerState<ConnectingScreen> createState() => _ConnectingScreenState();
}

class _ConnectingScreenState extends ConsumerState<ConnectingScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  bool get _isDemo => widget.kind == SourceType.demo;

  // Demo sources are added through the same M3U notifier, so they share its
  // submission state and progress reporting.
  bool get _isM3u =>
      widget.kind == SourceType.m3u || widget.kind == SourceType.demo;

  AsyncState<Source> _readSubmission() => _isM3u
      ? ref.read(addM3uSourceNotifierProvider).submission
      : ref.read(addXtreamSourceNotifierProvider).submission;

  Future<void> _run() async {
    if (_isDemo) {
      await ref.read(addM3uSourceNotifierProvider.notifier).startDemo();
    } else if (_isM3u) {
      await ref.read(addM3uSourceNotifierProvider.notifier).submit();
    } else {
      await ref.read(addXtreamSourceNotifierProvider.notifier).submit();
    }

    if (_readSubmission() is! AsyncSuccess<Source>) return; // error in build

    await ref.read(sourceSyncNotifierProvider.notifier).run();
    if (!mounted) return;

    final SyncProgress progress = ref.read(sourceSyncNotifierProvider);
    if (progress.isDone) {
      await context.router.replace(const SourceSuccessRoute());
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AsyncState<Source> submission = _isM3u
        ? ref.watch(addM3uSourceNotifierProvider).submission
        : ref.watch(addXtreamSourceNotifierProvider).submission;
    final SyncProgress progress = ref.watch(sourceSyncNotifierProvider);

    final Failures? failure = switch (submission) {
      AsyncError<Source>(:final Failures failure) => failure,
      AsyncIdle<Source>() => progress.isFailed ? progress.failure : null,
      AsyncLoading<Source>() => progress.isFailed ? progress.failure : null,
      AsyncSuccess<Source>() => progress.isFailed ? progress.failure : null,
    };

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space.x4),
          child: Center(
            child: failure != null
                ? _ErrorState(
                    failure: failure,
                    onRetry: _run,
                    formRouteName: _isDemo
                        ? WelcomeRoute.name
                        : _isM3u
                            ? M3uFormRoute.name
                            : XtreamFormRoute.name,
                  )
                : _ProgressState(
                    authLoading: submission is AsyncLoading<Source>,
                    progress: progress,
                  ),
          ),
        ),
      ),
    );
  }
}

class _ProgressState extends StatelessWidget {
  const _ProgressState({required this.authLoading, required this.progress});

  final bool authLoading;
  final SyncProgress progress;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final String label = authLoading
        ? AppLocalizations.of(context).connectingLabel
        : progress.statusLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularProgressIndicator(color: t.colors.accent),
        SizedBox(height: t.space.x6),
        Text(
          label,
          style: t.typography.body.copyWith(color: t.colors.textSecondary),
        ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.failure,
    required this.onRetry,
    required this.formRouteName,
  });

  final Failures failure;
  final VoidCallback onRetry;
  final String formRouteName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      title: l.connectingErrorTitle,
      message: failure.computeErrorMessage(),
      action: Column(
        children: <Widget>[
          PrimaryButton(label: l.commonRetry, expand: false, onPressed: onRetry),
          SizedBox(height: context.appTheme.space.x2),
          SecondaryButton(
            label: l.commonEdit,
            expand: false,
            onPressed: () =>
                context.router.popUntilRouteWithName(formRouteName),
          ),
        ],
      ),
    );
  }
}
