import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/iptv_epg.dart";
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
  const LiveChannelsView({this.onOpenChannel, this.hideAdult = false, super.key});

  /// Invoked with the tapped channel.
  final void Function(Channel channel)? onOpenChannel;

  /// Hides adult-flagged categories and their channels (parental control).
  final bool hideAdult;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<Channel>> channelsState =
        ref.watch(liveChannelsNotifierProvider);
    final String selected = ref.watch(selectedLiveCategoryProvider);
    final LiveViewMode mode = ref.watch(liveViewModeNotifierProvider);
    final ISet<String> adultIds = hideAdult
        ? _adultCategoryIds(ref.watch(liveCategoriesNotifierProvider))
        : const ISetConst<String>(<String>{});

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
                ref.read(liveViewModeNotifierProvider.notifier).toggle(),
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
                    title: "Erreur",
                    message: failure.computeErrorMessage(),
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
        ref.watch(liveCategoriesNotifierProvider);
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
              label: "Tous",
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

class _ChannelList extends ConsumerWidget {
  const _ChannelList({required this.channels, required this.onOpenChannel});

  final IList<Channel> channels;
  final void Function(Channel channel)? onOpenChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final DateTime now = DateTime.now().toUtc();
    final DateTime bucket =
        DateTime.utc(now.year, now.month, now.day, now.hour, now.minute);
    final Map<String, EpgEntry> nowMap = ref.watch(epgNowProvider(bucket));

    if (channels.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.tv_off,
          title: "Aucune chaîne",
          message: "Cette catégorie ne contient aucune chaîne.",
        ),
      );
    }

    return ListView.builder(
      // Clear the floating glass nav bar (bottom inset set by the shell).
      padding: EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom),
      itemCount: channels.length,
      itemBuilder: (BuildContext context, int index) {
        final Channel channel = channels[index];
        final EpgEntry? entry =
            channel.epgChannelId == null ? null : nowMap[channel.epgChannelId];
        return ChannelRow(
          name: channel.name,
          logoUrl: channel.logoUrl,
          nowPlaying: entry?.title,
          progress: entry?.progressAt(bucket),
          isLive: true,
          onTap: () => onOpenChannel?.call(channel),
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
