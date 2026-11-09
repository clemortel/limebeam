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

const double _kConnectingBarHeight = 4;

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
    WidgetsBinding.instance.addPostFrameCallback((_) => _finish(_submit()));
  }

  bool get _isDemo => widget.kind == SourceType.demo;

  // Demo sources are added through the same M3U notifier, so they share its
  // submission state and progress reporting.
  bool get _isM3u =>
      widget.kind == SourceType.m3u || widget.kind == SourceType.demo;

  /// Adds the source and syncs it under the one sync gate: the add itself
  /// starts the sync, so there is no second `run()` that could be a no-op.
  /// Reads nothing from [ref] after an await unless still [mounted].
  Future<void> _finish(Future<SyncProgress?> attempt) async {
    final SyncProgress? progress = await attempt;
    if (!mounted || progress == null || !progress.isDone) return;
    await context.router.replace(const SourceSuccessRoute());
  }

  /// Retry: the notifier decides between re-syncing an added source and
  /// re-submitting a failed add, so a retry never duplicates the source.
  Future<SyncProgress?> _retry() {
    if (_isM3u) return ref.read(addM3uSourceProvider.notifier).retry();
    return ref.read(addXtreamSourceProvider.notifier).retry();
  }

  Future<SyncProgress?> _submit() {
    if (_isDemo) return ref.read(addM3uSourceProvider.notifier).startDemo();
    if (_isM3u) return ref.read(addM3uSourceProvider.notifier).submit();
    return ref.read(addXtreamSourceProvider.notifier).submit();
  }

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final AsyncState<Source> submission = _isM3u
        ? ref.watch(addM3uSourceProvider).submission
        : ref.watch(addXtreamSourceProvider).submission;
    final bool syncBusy = _isM3u
        ? ref.watch(addM3uSourceProvider).syncBusy
        : ref.watch(addXtreamSourceProvider).syncBusy;
    final SyncProgress progress = ref.watch(sourceSyncProvider);
    final AppLocalizations l = AppLocalizations.of(context);

    final Failures? failure = switch (submission) {
      AsyncError<Source>(:final Failures failure) => failure,
      AsyncIdle<Source>() => progress.isFailed ? progress.failure : null,
      AsyncLoading<Source>() => progress.isFailed ? progress.failure : null,
      AsyncSuccess<Source>() => progress.isFailed ? progress.failure : null,
    };

    final String? message = syncBusy ? l.sourcesSyncBusy : failure?.localized(l);

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(t.space.x4),
          child: Center(
            child: message != null
                ? _ErrorState(
                    message: message,
                    onRetry: () => _finish(_retry()),
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
    final AppLocalizations l = AppLocalizations.of(context);
    final String label =
        authLoading ? l.connectingLabel : progress.step.label(l);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        CircularProgressIndicator(color: t.colors.accent),
        SizedBox(height: t.space.x6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: t.typography.body.copyWith(color: t.colors.textPrimary),
        ),
        if (!authLoading && progress.stepNumber > 0) ...<Widget>[
          SizedBox(height: t.space.x2),
          Text(
            l.onboardingSyncStepOf(progress.stepNumber, kSyncStepCount),
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          SizedBox(height: t.space.x4),
          ClipRRect(
            borderRadius: t.radius.fullAll,
            child: LinearProgressIndicator(
              value: progress.stepNumber / kSyncStepCount,
              minHeight: _kConnectingBarHeight,
              color: t.colors.accent,
              backgroundColor: t.colors.bgElevated,
            ),
          ),
        ],
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({
    required this.message,
    required this.onRetry,
    required this.formRouteName,
  });

  final String message;
  final VoidCallback onRetry;
  final String formRouteName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l = AppLocalizations.of(context);
    return EmptyState(
      icon: Icons.error_outline,
      title: l.connectingErrorTitle,
      message: message,
      action: Column(
        children: <Widget>[
          PrimaryButton(
            label: l.commonRetry,
            expand: false,
            onPressed: onRetry,
          ),
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
