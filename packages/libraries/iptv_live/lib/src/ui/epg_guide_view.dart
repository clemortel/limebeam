import "package:fast_immutable_collections/fast_immutable_collections.dart";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart"
    hide AsyncData, AsyncError, AsyncLoading, AsyncValue;
import "package:iptv_core/iptv_core.dart";
import "package:iptv_epg/iptv_epg.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../models/channel.dart";

const double _kPxPerMinute = 4;
const int _kHoursBefore = 1;
const int _kHoursAfter = 3;
const double _kRowHeight = 64;
const double _kLabelColWidth = 96;
const double _kHeaderHeight = 28;
const int _kMaxGuideChannels = 50;
const double _kMinCellWidth = 2;
const int _kMinutesPerHour = 60;
const int _kSkeletonRows = 8;
const double _kNowLineWidth = 2;

/// EPG guide grid (§4.3.2): channels down the Y axis, time across X. A single
/// 2D scroll surface; the current programme is highlighted with its progress.
/// Tapping a row plays that channel live.
class EpgGuideView extends ConsumerWidget {
  const EpgGuideView({required this.channels, this.onOpenChannel, super.key});

  final IList<Channel> channels;
  final void Function(Channel channel)? onOpenChannel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppTheme t = context.appTheme;
    final AsyncState<IList<EpgEntry>> epgState = ref.watch(epgNotifierProvider);
    final IList<EpgEntry> entries = switch (epgState) {
      AsyncSuccess<IList<EpgEntry>>(:final IList<EpgEntry> data) => data,
      _ => const IListConst<EpgEntry>(<EpgEntry>[]),
    };
    if (entries.isEmpty) {
      final bool loading = epgState is AsyncLoading<IList<EpgEntry>> ||
          epgState is AsyncIdle<IList<EpgEntry>>;
      if (loading) return _GuideSkeleton(channels: channels);
      return const Center(
        child: EmptyState(
          icon: Icons.calendar_today_outlined,
          title: "Guide indisponible",
          message: "Aucune donnée EPG pour cette source.",
        ),
      );
    }

    final DateTime now = DateTime.now().toUtc();
    final DateTime windowStart =
        DateTime.utc(now.year, now.month, now.day, now.hour)
            .subtract(const Duration(hours: _kHoursBefore));
    final DateTime windowEnd =
        windowStart.add(const Duration(hours: _kHoursBefore + _kHoursAfter));
    final int totalMinutes = windowEnd.difference(windowStart).inMinutes;
    final double gridWidth = totalMinutes * _kPxPerMinute;

    final Map<String, List<EpgEntry>> byChannel = <String, List<EpgEntry>>{};
    for (final EpgEntry e in entries) {
      if (e.stop.isAfter(windowStart) && e.start.isBefore(windowEnd)) {
        (byChannel[e.channelId] ??= <EpgEntry>[]).add(e);
      }
    }

    final List<Channel> visible =
        channels.take(_kMaxGuideChannels).toList(growable: false);
    final double nowOffset =
        (now.difference(windowStart).inMinutes * _kPxPerMinute)
            .clamp(0, gridWidth);

    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Stack(
          children: <Widget>[
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _TimeHeader(
                  windowStart: windowStart,
                  totalMinutes: totalMinutes,
                ),
                for (final Channel channel in visible)
                  _GuideRow(
                    channel: channel,
                    programmes: channel.epgChannelId == null
                        ? const <EpgEntry>[]
                        : byChannel[channel.epgChannelId] ?? const <EpgEntry>[],
                    windowStart: windowStart,
                    windowEnd: windowEnd,
                    gridWidth: gridWidth,
                    now: now,
                    onWatch: () => onOpenChannel?.call(channel),
                  ),
              ],
            ),
            Positioned(
              left: _kLabelColWidth + nowOffset,
              top: _kHeaderHeight,
              child: Container(
                width: _kNowLineWidth,
                height: visible.length * _kRowHeight,
                color: t.colors.live,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TimeHeader extends StatelessWidget {
  const _TimeHeader({required this.windowStart, required this.totalMinutes});

  final DateTime windowStart;
  final int totalMinutes;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Row(
      children: <Widget>[
        const SizedBox(width: _kLabelColWidth, height: _kHeaderHeight),
        SizedBox(
          width: totalMinutes * _kPxPerMinute,
          height: _kHeaderHeight,
          child: Stack(
            children: <Widget>[
              for (int m = 0; m <= totalMinutes; m += _kMinutesPerHour)
                Positioned(
                  left: m * _kPxPerMinute,
                  top: 0,
                  child: Text(
                    _formatHour(windowStart.add(Duration(minutes: m))),
                    style: t.typography.caption
                        .copyWith(color: t.colors.textTertiary),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GuideRow extends StatelessWidget {
  const _GuideRow({
    required this.channel,
    required this.programmes,
    required this.windowStart,
    required this.windowEnd,
    required this.gridWidth,
    required this.now,
    required this.onWatch,
  });

  final Channel channel;
  final List<EpgEntry> programmes;
  final DateTime windowStart;
  final DateTime windowEnd;
  final double gridWidth;
  final DateTime now;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _ChannelLabel(channel: channel, onTap: onWatch),
        SizedBox(
          width: gridWidth,
          height: _kRowHeight,
          child: Stack(
            children: <Widget>[
              for (final EpgEntry e in programmes)
                _ProgrammeCell(
                  entry: e,
                  windowStart: windowStart,
                  windowEnd: windowEnd,
                  now: now,
                  onWatch: onWatch,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ChannelLabel extends StatelessWidget {
  const _ChannelLabel({required this.channel, required this.onTap});

  final Channel channel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: _kLabelColWidth,
        height: _kRowHeight,
        padding: EdgeInsets.symmetric(horizontal: t.space.x2),
        alignment: Alignment.centerLeft,
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: t.colors.borderSubtle)),
        ),
        child: Text(
          channel.name,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: t.typography.caption.copyWith(color: t.colors.textPrimary),
        ),
      ),
    );
  }
}

class _ProgrammeCell extends StatelessWidget {
  const _ProgrammeCell({
    required this.entry,
    required this.windowStart,
    required this.windowEnd,
    required this.now,
    required this.onWatch,
  });

  final EpgEntry entry;
  final DateTime windowStart;
  final DateTime windowEnd;
  final DateTime now;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final DateTime cellStart =
        entry.start.isBefore(windowStart) ? windowStart : entry.start;
    final DateTime cellEnd =
        entry.stop.isAfter(windowEnd) ? windowEnd : entry.stop;
    final double left =
        cellStart.difference(windowStart).inMinutes * _kPxPerMinute;
    final double width =
        (cellEnd.difference(cellStart).inMinutes * _kPxPerMinute)
            .clamp(_kMinCellWidth, double.infinity);
    final bool isNow = entry.isLiveAt(now);

    return Positioned(
      left: left,
      top: 0,
      bottom: 0,
      width: width,
      child: GestureDetector(
        onTap: () => _showProgrammeSheet(context, entry, onWatch),
        child: Container(
          margin: EdgeInsets.all(t.space.x1),
          padding: EdgeInsets.symmetric(
            horizontal: t.space.x2,
            vertical: t.space.x1,
          ),
          decoration: BoxDecoration(
            color: isNow ? t.colors.accentSubtle : t.colors.bgSurface,
            borderRadius: t.radius.smAll,
            border: Border.all(
              color: isNow ? t.colors.accent : t.colors.borderSubtle,
            ),
          ),
          child: Text(
            entry.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: t.typography.caption.copyWith(
              color: isNow ? t.colors.textPrimary : t.colors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _GuideSkeleton extends StatelessWidget {
  const _GuideSkeleton({required this.channels});

  final IList<Channel> channels;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final int rows = channels.isEmpty
        ? _kSkeletonRows
        : channels.length.clamp(1, _kMaxGuideChannels);
    return ListView.builder(
      padding: EdgeInsets.symmetric(vertical: t.space.x1),
      itemCount: rows,
      itemBuilder: (BuildContext context, int index) => Padding(
        padding: EdgeInsets.symmetric(
          horizontal: t.space.x2,
          vertical: t.space.x1,
        ),
        child: Row(
          children: <Widget>[
            SkeletonBox(
              width: _kLabelColWidth,
              height: _kRowHeight - t.space.x2,
              borderRadius: t.radius.smAll,
            ),
            SizedBox(width: t.space.x2),
            Expanded(
              child: SkeletonBox(
                height: _kRowHeight - t.space.x2,
                borderRadius: t.radius.smAll,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

void _showProgrammeSheet(
  BuildContext context,
  EpgEntry entry,
  VoidCallback onWatch,
) {
  AppBottomSheet.show<void>(
    context,
    title: entry.title,
    child: _ProgrammeDetails(
      entry: entry,
      onWatch: () {
        Navigator.of(context).maybePop();
        onWatch();
      },
    ),
  );
}

class _ProgrammeDetails extends StatelessWidget {
  const _ProgrammeDetails({required this.entry, required this.onWatch});

  final EpgEntry entry;
  final VoidCallback onWatch;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Padding(
      padding: EdgeInsets.all(t.space.x4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            "${_formatHour(entry.start)} – ${_formatHour(entry.stop)}",
            style: t.typography.caption.copyWith(color: t.colors.textSecondary),
          ),
          if (entry.description.isNotEmpty) ...<Widget>[
            SizedBox(height: t.space.x3),
            Text(
              entry.description,
              style: t.typography.body.copyWith(color: t.colors.textSecondary),
            ),
          ],
          SizedBox(height: t.space.x4),
          PrimaryButton(label: "Regarder", onPressed: onWatch),
        ],
      ),
    );
  }
}

String _formatHour(DateTime utc) {
  final DateTime local = utc.toLocal();
  final String hh = local.hour.toString().padLeft(2, "0");
  final String mm = local.minute.toString().padLeft(2, "0");
  return "$hh:$mm";
}
