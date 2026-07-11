import "dart:async";

import "package:dpad/dpad.dart";
import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/iptv_epg.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/channel.dart";
import "../models/live_category.dart";
import "../riverpods/live_categories_notifier.dart";
import "../riverpods/live_channels_notifier.dart";
import "../riverpods/providers.dart";
import "epg_guide_view.dart";

/// TV — live channel list (§4.3.1): category chips + channel rows with
/// now-playing from EPG. Reads providers via ref; no prop-drilling.
class LiveChannelsView extends ConsumerWidget {
  const LiveChannelsView({
    this.onOpenChannel,
    this.hideAdult = false,
    this.preview,
    this.onChannelDwell,
    super.key,
  });

  /// Invoked with the tapped channel.
  final void Function(Channel channel)? onOpenChannel;

  /// Hides adult-flagged categories and their channels (parental control).
  final bool hideAdult;

  /// TV only: a persistent preview widget (see iptv_player `LivePreview`) shown
  /// as a banner above the channel list. The caller owns it and updates the
  /// previewed stream in response to [onChannelDwell]; kept as one widget so
  /// its player isn't recreated on every channel change.
  final Widget? preview;

  /// TV only: fired with the channel the remote has rested on for the dwell
  /// delay (null while none) so the caller can drive [preview].
  final void Function(Channel? channel)? onChannelDwell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<Channel>> channelsState =
        ref.watch(liveChannelsProvider);
    final String selected = ref.watch(selectedLiveCategoryProvider);
    final LiveViewMode mode = ref.watch(liveViewModeProvider);
    final ISet<String> adultIds = hideAdult
        ? _adultCategoryIds(ref.watch(liveCategoriesProvider))
        : const ISetConst<String>(<String>{});

    // TV: two panes — categories on the left, channels (or the guide) on the
    // right — so D-pad flows left→right and selecting a channel is one clear
    // action, instead of category chips stacked above a full-width list.
    if (FormFactorScope.isTv(context)) {
      return Scaffold(
        backgroundColor: t.colors.bgBase,
        body: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _CategoryColumn(hideAdult: hideAdult),
              Expanded(
                child: switch (channelsState) {
                  AsyncIdle<IList<Channel>>() => const _ChannelListSkeleton(),
                  AsyncLoading<IList<Channel>>() =>
                    const _ChannelListSkeleton(),
                  AsyncError<IList<Channel>>(:final Failures failure) => Center(
                      child: EmptyState(
                        icon: Icons.error_outline,
                        title: AppLocalizations.of(context).commonError,
                        message: failure.localized(AppLocalizations.of(context)),
                      ),
                    ),
                  AsyncSuccess<IList<Channel>>(:final IList<Channel> data) =>
                    mode == LiveViewMode.guide
                        ? EpgGuideView(
                            channels: _visible(data, selected, adultIds),
                            onOpenChannel: onOpenChannel,
                          )
                        : Column(
                            children: <Widget>[
                              if (preview != null) _PreviewBanner(child: preview!),
                              Expanded(
                                child: DpadRegion(
                                  verticalEdge: DpadEdgeBehavior.stop,
                                  child: _ChannelList(
                                    channels: _visible(data, selected, adultIds),
                                    onOpenChannel: onOpenChannel,
                                    onChannelDwell: onChannelDwell,
                                    autofocusFirst: false,
                                  ),
                                ),
                              ),
                            ],
                          ),
                },
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: t.colors.bgBase,
      appBar: AppBar(
        backgroundColor: t.colors.bgBase,
        title: Text("TV", style: t.typography.h1),
        actions: <Widget>[
          IconButton(
            icon: Icon(
              mode == LiveViewMode.guide
                  ? Icons.view_list_outlined
                  : Icons.calendar_view_week_outlined,
              color: t.colors.textPrimary,
            ),
            onPressed: () =>
                ref.read(liveViewModeProvider.notifier).toggle(),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          _CategoryChips(hideAdult: hideAdult),
          Expanded(
            child: switch (channelsState) {
              AsyncIdle<IList<Channel>>() => const _ChannelListSkeleton(),
              AsyncLoading<IList<Channel>>() => const _ChannelListSkeleton(),
              AsyncError<IList<Channel>>(:final Failures failure) => Center(
                  child: EmptyState(
                    icon: Icons.error_outline,
                    title: AppLocalizations.of(context).commonError,
                    message: failure.localized(AppLocalizations.of(context)),
                  ),
                ),
              AsyncSuccess<IList<Channel>>(:final IList<Channel> data) =>
                mode == LiveViewMode.guide
                    ? EpgGuideView(
                        channels: _visible(data, selected, adultIds),
                        onOpenChannel: onOpenChannel,
                      )
                    : _ChannelList(
                        channels: _visible(data, selected, adultIds),
                        onOpenChannel: onOpenChannel,
                      ),
            },
          ),
        ],
      ),
    );
  }

  IList<Channel> _visible(
    IList<Channel> all,
    String selected,
    ISet<String> adultIds,
  ) {
    return all
        .where(
          (Channel c) =>
              !adultIds.contains(c.categoryId) &&
              (selected.isEmpty || c.categoryId == selected),
        )
        .toIList();
  }
}

ISet<String> _adultCategoryIds(AsyncState<IList<LiveCategory>> state) {
  final IList<LiveCategory> categories = switch (state) {
    AsyncSuccess<IList<LiveCategory>>(:final IList<LiveCategory> data) => data,
    _ => const IListConst<LiveCategory>(<LiveCategory>[]),
  };
  return categories
      .where((LiveCategory c) => c.isAdult)
      .map((LiveCategory c) => c.id)
      .toISet();
}

class _CategoryChips extends ConsumerWidget {
  const _CategoryChips({required this.hideAdult});

  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<LiveCategory>> state =
        ref.watch(liveCategoriesProvider);
    final String selected = ref.watch(selectedLiveCategoryProvider);

    final IList<LiveCategory> all = switch (state) {
      AsyncSuccess<IList<LiveCategory>>(:final IList<LiveCategory> data) => data,
      _ => const IListConst<LiveCategory>(<LiveCategory>[]),
    };
    final IList<LiveCategory> categories = hideAdult
        ? all.where((LiveCategory c) => !c.isAdult).toIList()
        : all;

    return SizedBox(
      height: 34 + t.space.x4,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.x4,
          vertical: t.space.x2,
        ),
        itemCount: categories.length + 1,
        separatorBuilder: (BuildContext c, int i) =>
            SizedBox(width: t.space.x2),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) {
            return FilterChipX(
              label: AppLocalizations.of(context).commonAll,
              selected: selected.isEmpty,
              onTap: () =>
                  ref.read(selectedLiveCategoryProvider.notifier).select(""),
            );
          }
          final LiveCategory category = categories[index - 1];
          return FilterChipX(
            label: category.name,
            selected: selected == category.id,
            onTap: () => ref
                .read(selectedLiveCategoryProvider.notifier)
                .select(category.id),
          );
        },
      ),
    );
  }
}

/// Fixed width (pre-TV-scale) of the left category column in the two-pane TV
/// layout.
const double _kCategoryColumnWidth = 240;

/// TV two-pane left column: a guide/list toggle plus a vertical, focusable
/// category list. Category selection follows focus so the channel pane on the
/// right filters live as the user moves down the list.
class _CategoryColumn extends ConsumerWidget {
  const _CategoryColumn({required this.hideAdult});

  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AppLocalizations l = AppLocalizations.of(context);
    final AsyncState<IList<LiveCategory>> state =
        ref.watch(liveCategoriesProvider);
    final String selected = ref.watch(selectedLiveCategoryProvider);
    final LiveViewMode mode = ref.watch(liveViewModeProvider);

    final IList<LiveCategory> all = switch (state) {
      AsyncSuccess<IList<LiveCategory>>(:final IList<LiveCategory> data) => data,
      _ => const IListConst<LiveCategory>(<LiveCategory>[]),
    };
    final IList<LiveCategory> categories = hideAdult
        ? all.where((LiveCategory c) => !c.isAdult).toIList()
        : all;

    return Container(
      width: _kCategoryColumnWidth * AppTheme.tvTokenScale,
      color: t.colors.bgSurface,
      padding: EdgeInsets.symmetric(vertical: t.space.x4),
      child: DpadRegion(
        verticalEdge: DpadEdgeBehavior.stop,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.x3),
              child: _CategoryTile(
                icon: mode == LiveViewMode.guide
                    ? Icons.view_list_outlined
                    : Icons.calendar_view_week_outlined,
                label: mode == LiveViewMode.guide ? "Liste" : "Guide",
                selected: false,
                onSelectOnFocus: false,
                onActivate: () =>
                    ref.read(liveViewModeProvider.notifier).toggle(),
              ),
            ),
            SizedBox(height: t.space.x2),
            Expanded(
              child: ListView.builder(
                padding: EdgeInsets.symmetric(horizontal: t.space.x3),
                itemCount: categories.length + 1,
                itemBuilder: (BuildContext context, int index) {
                  if (index == 0) {
                    return _CategoryTile(
                      label: l.commonAll,
                      selected: selected.isEmpty,
                      onActivate: () => ref
                          .read(selectedLiveCategoryProvider.notifier)
                          .select(""),
                    );
                  }
                  final LiveCategory category = categories[index - 1];
                  return _CategoryTile(
                    label: category.name,
                    selected: selected == category.id,
                    onActivate: () => ref
                        .read(selectedLiveCategoryProvider.notifier)
                        .select(category.id),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    required this.label,
    required this.selected,
    required this.onActivate,
    this.icon,
    this.onSelectOnFocus = true,
  });

  final String label;
  final bool selected;
  final VoidCallback onActivate;
  final IconData? icon;

  /// Category tiles select as focus lands on them (live-filter the channel
  /// pane); the toggle tile only acts on OK.
  final bool onSelectOnFocus;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color color = selected ? t.colors.accent : t.colors.textPrimary;
    return Padding(
      padding: EdgeInsets.only(bottom: t.space.x1),
      child: IptvFocusable(
        onTap: onActivate,
        onFocusChange: onSelectOnFocus
            ? (bool focused) {
                if (focused && !selected) onActivate();
              }
            : null,
        focusBorderRadius: t.radius.mdAll,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: t.space.x3,
            vertical: t.space.x3,
          ),
          decoration: BoxDecoration(
            color: selected ? t.colors.accentSubtle : null,
            borderRadius: t.radius.mdAll,
          ),
          child: Row(
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Icon(icon, size: 20, color: color),
                SizedBox(width: t.space.x2),
              ],
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: t.typography.body.copyWith(
                    color: color,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Delay a channel must stay focused before its preview is requested — long
/// enough that scrolling through the list doesn't fire a stream per row.
const Duration _kPreviewDwell = Duration(milliseconds: 1200);

/// Fixed height (pre-TV-scale) of the preview banner above the channel list.
const double _kPreviewHeight = 230;

/// Rounded container that hosts the live preview above the channel list.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.all(t.space.x3),
      child: ClipRRect(
        borderRadius: t.radius.lgAll,
        child: SizedBox(
          height: _kPreviewHeight * AppTheme.tvTokenScale,
          width: double.infinity,
          child: ColoredBox(color: t.colors.bgElevated, child: child),
        ),
      ),
    );
  }
}

class _ChannelList extends ConsumerStatefulWidget {
  const _ChannelList({
    required this.channels,
    required this.onOpenChannel,
    this.onChannelDwell,
    this.autofocusFirst = true,
  });

  final IList<Channel> channels;
  final void Function(Channel channel)? onOpenChannel;
  final void Function(Channel? channel)? onChannelDwell;

  /// Whether the first row grabs focus on build. False in the TV two-pane so
  /// the category column keeps initial focus (the user steps Right into the
  /// channels), avoiding two competing autofocus targets.
  final bool autofocusFirst;

  @override
  ConsumerState<_ChannelList> createState() => _ChannelListState();
}

class _ChannelListState extends ConsumerState<_ChannelList> {
  Timer? _dwellTimer;
  Channel? _pending;

  @override
  void dispose() {
    _dwellTimer?.cancel();
    super.dispose();
  }

  /// Arms the dwell timer when a row gains focus; the preview is requested only
  /// once the remote has rested on it for [_kPreviewDwell].
  void _onRowFocus(Channel channel, bool focused) {
    if (!focused || widget.onChannelDwell == null) return;
    _pending = channel;
    _dwellTimer?.cancel();
    _dwellTimer = Timer(_kPreviewDwell, () {
      if (mounted) widget.onChannelDwell?.call(_pending);
    });
  }

  @override
  Widget build(BuildContext context) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime bucket =
        DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
    final Map<String, EpgEntry> nowMap = ref.watch(epgNowProvider(bucket));

    if (widget.channels.isEmpty) {
      return Center(
        child: EmptyState(
          icon: Icons.tv_off,
          title: AppLocalizations.of(context).liveEmptyTitle,
          message: AppLocalizations.of(context).liveEmptyMessage,
        ),
      );
    }

    final bool dwellEnabled = widget.onChannelDwell != null;
    return ListView.builder(
      // Clear the floating glass nav bar (bottom inset set by the shell).
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: widget.channels.length,
      itemBuilder: (BuildContext context, int index) {
        final Channel channel = widget.channels[index];
        final EpgEntry? entry =
            channel.epgChannelId == null ? null : nowMap[channel.epgChannelId];
        return ChannelRow(
          name: channel.name,
          logoUrl: channel.logoUrl,
          nowPlaying: entry?.title,
          progress: entry?.progressAt(bucket),
          isLive: true,
          autofocus: widget.autofocusFirst &&
              index == 0 &&
              FormFactorScope.isTv(context),
          onFocusChange: dwellEnabled
              ? (bool focused) => _onRowFocus(channel, focused)
              : null,
          onTap: () => widget.onOpenChannel?.call(channel),
        );
      },
    );
  }
}

class _ChannelListSkeleton extends StatelessWidget {
  const _ChannelListSkeleton();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return ListView.separated(
      padding: EdgeInsets.all(t.space.x4),
      itemCount: 10,
      separatorBuilder: (BuildContext c, int i) => SizedBox(height: t.space.x3),
      itemBuilder: (BuildContext c, int i) => Row(
        children: <Widget>[
          SkeletonBox(width: 48, height: 48, borderRadius: t.radius.smAll),
          SizedBox(width: t.space.x3),
          const Expanded(child: SkeletonBox(height: 16)),
        ],
      ),
    );
  }
}
