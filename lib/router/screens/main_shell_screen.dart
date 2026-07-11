import "package:auto_route/auto_route.dart";
import "package:dpad/dpad.dart";
import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

const double _kTabBarHeight = 64;

/// Collapsed width of the TV side rail — an icon-only strip that always
/// occupies the left edge. Scaled by [AppTheme.tvTokenScale].
const double _kRailCollapsedWidth = 72;

/// Expanded width when a rail entry is focused. The rail grows OVER the content
/// (overlay, no reflow) to reveal labels, Netflix-style, then collapses back.
const double _kRailExpandedWidth = 240;

/// Icon size for the TV side-rail entries.
const double _kRailIconSize = 28;

/// Icon size for the phone bottom-bar tab entries.
const double _kTabIconSize = 24;

/// The tab routes, shared by the phone bottom bar and the TV side rail.
const List<PageRouteInfo<dynamic>> _kTabRoutes = <PageRouteInfo<dynamic>>[
  HomeTabRoute(),
  LiveTabRoute(),
  FilmsTabRoute(),
  SeriesTabRoute(),
  SearchTabRoute(),
  SettingsTabRoute(),
];

/// Main shell with the 5 tabs (spec §3). The active tab is marked by a filled
/// icon + bolder label + accent color (not color alone — WCAG 1.4.1).
///
/// Adapts to the form factor: phone/tablet keep the floating bottom glass pill;
/// TV switches to a focusable left side rail for D-pad/remote navigation.
@RoutePage()
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    if (FormFactorScope.isTv(context)) return const _TvShell();
    return AutoTabsScaffold(
      backgroundColor: context.appTheme.colors.bgBase,
      // Let page content scroll *under* the translucent tab bar so the glass
      // has something to blur/refract (otherwise it reads as a solid bar).
      extendBody: true,
      // Instant tab switch: the default cross-fade stretches a tab's lazy
      // first build across the animation (stutters, worst on the Search tab's
      // first TextField). An instant switch makes it a single frame instead.
      transitionBuilder: (BuildContext context, Widget child, _) => child,
      routes: _kTabRoutes,
      bottomNavigationBuilder: (BuildContext context, TabsRouter tabsRouter) =>
          _TabBar(tabsRouter: tabsRouter),
    );
  }
}

/// 10-foot shell: a slim icon rail on the left edge that expands OVER the
/// content when focused. The content fills the whole width (behind the
/// collapsed strip) so posters get maximum room — the rail no longer pushes
/// it right (Netflix-style).
class _TvShell extends StatelessWidget {
  const _TvShell();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    const double collapsed = _kRailCollapsedWidth * AppTheme.tvTokenScale;
    return AutoTabsRouter(
      routes: _kTabRoutes,
      transitionBuilder: (BuildContext context, Widget child, _) => child,
      builder: (BuildContext context, Widget child) {
        final TabsRouter tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
          backgroundColor: t.colors.bgBase,
          body: Stack(
            children: <Widget>[
              // Content occupies the full width; only the collapsed icon strip
              // is reserved on the left. TV overscan margin on the other three
              // edges (the rail owns the left edge).
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.only(left: collapsed),
                  child: Padding(
                    padding: tvOverscan(context, includeLeft: false),
                    child: child,
                  ),
                ),
              ),
              // The rail draws on top and grows to the right when focused.
              Positioned(
                top: 0,
                left: 0,
                bottom: 0,
                child: _SideRail(tabsRouter: tabsRouter),
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Slim rail that widens to reveal labels while it (or one of its buttons) has
/// focus. Focus tracking is done with a wrapping [Focus] whose `hasFocus`
/// covers the whole subtree, so entering any button expands and leaving to the
/// content collapses.
class _SideRail extends StatefulWidget {
  const _SideRail({required this.tabsRouter});

  final TabsRouter tabsRouter;

  @override
  State<_SideRail> createState() => _SideRailState();
}

class _SideRailState extends State<_SideRail> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    const double collapsed = _kRailCollapsedWidth * AppTheme.tvTokenScale;
    const double expanded = _kRailExpandedWidth * AppTheme.tvTokenScale;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (bool hasFocus) {
        if (hasFocus != _expanded) setState(() => _expanded = hasFocus);
      },
      // A D-pad region so ▲/▼ move between the tab buttons (region-first,
      // rather than the beam escaping to a content poster up-and-right) and
      // only ▶ leaves the rail into the content.
      child: DpadRegion(
        verticalEdge: DpadEdgeBehavior.stop,
        horizontalEdge: DpadEdgeBehavior.leave,
        child: AnimatedContainer(
          duration: t.motion.fast,
          curve: Curves.easeOutCubic,
          width: _expanded ? expanded : collapsed,
          decoration: BoxDecoration(
            color: t.colors.bgSurface,
            // A soft shadow lifts the expanded rail off the content it covers.
            boxShadow: _expanded
                ? <BoxShadow>[
                    BoxShadow(
                      color: t.colors.bgBase.withValues(alpha: 0.6),
                      blurRadius: 24,
                      offset: const Offset(4, 0),
                    ),
                  ]
                : const <BoxShadow>[],
          ),
          padding: EdgeInsets.symmetric(vertical: t.space.x6),
          child: SafeArea(
            right: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                for (int i = 0; i < _kTabs.length; i++)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: t.space.x2,
                      vertical: t.space.x1,
                    ),
                    child: _RailButton(
                      item: _kTabs[i],
                      label: _tabLabel(context, i),
                      selected: widget.tabsRouter.activeIndex == i,
                      expanded: _expanded,
                      // Anchor the remote on the active tab so focus is never
                      // null on TV; the rail opens expanded, then collapses as
                      // soon as the user D-pads right into the content.
                      autofocus: widget.tabsRouter.activeIndex == i,
                      onTap: () => widget.tabsRouter.setActiveIndex(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.label,
    required this.selected,
    required this.expanded,
    required this.autofocus,
    required this.onTap,
  });

  final _TabItem item;
  final String label;
  final bool selected;
  final bool expanded;
  final bool autofocus;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color color = selected ? t.colors.accent : t.colors.textSecondary;
    final TextStyle labelStyle = (selected
            ? t.typography.body.copyWith(fontWeight: FontWeight.w700)
            : t.typography.body)
        .copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: IptvFocusable(
        autofocus: autofocus,
        onTap: onTap,
        focusBorderRadius: t.radius.lgAll,
        child: Container(
          height: _kRailIconSize * AppTheme.tvTokenScale + t.space.x6,
          padding: EdgeInsets.symmetric(horizontal: t.space.x3),
          decoration: BoxDecoration(
            color: selected ? t.colors.accentSubtle : null,
            borderRadius: t.radius.lgAll,
          ),
          // Icon stays pinned left so it doesn't jump when the label appears.
          child: Row(
            children: <Widget>[
              Icon(
                selected ? item.activeIcon : item.icon,
                size: _kRailIconSize * AppTheme.tvTokenScale,
                color: color,
              ),
              // Reveal the label only when expanded; Expanded+clip keeps the
              // text from overflowing mid-animation while the width grows.
              if (expanded) ...<Widget>[
                SizedBox(width: t.space.x3),
                Expanded(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.clip,
                    softWrap: false,
                    style: labelStyle,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  const _TabItem(this.icon, this.activeIcon);
  final IconData icon;
  final IconData activeIcon;
}

const List<_TabItem> _kTabs = <_TabItem>[
  _TabItem(Icons.home_outlined, Icons.home),
  _TabItem(Icons.live_tv_outlined, Icons.live_tv),
  _TabItem(Icons.movie_outlined, Icons.movie),
  _TabItem(Icons.video_library_outlined, Icons.video_library),
  _TabItem(Icons.search_outlined, Icons.search),
  _TabItem(Icons.settings_outlined, Icons.settings),
];

/// Localized label for tab [index] (order matches [_kTabs]).
String _tabLabel(BuildContext context, int index) {
  final AppLocalizations l = AppLocalizations.of(context);
  return <String>[
    l.tabHome,
    l.tabTv,
    l.browseMovies,
    l.browseSeries,
    l.tabSearch,
    l.tabSettings,
  ][index];
}

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabsRouter});

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    // Hide the floating nav while the keyboard is up (e.g. the search field):
    // it would otherwise sit just above the keyboard and force its
    // BackdropFilter to re-blur on every keystroke/keyboard frame — the main
    // source of jank in the search flow.
    if (MediaQuery.viewInsetsOf(context).bottom > 0) {
      return const SizedBox.shrink();
    }
    final double bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    // Floating frosted pill (iOS-26 style): inset from the edges and rounded so
    // page content scrolls visibly *under and around* it. Glass falls back to a
    // solid surface under "Reduce transparency" / high contrast (see
    // GlassSurface).
    return Padding(
      padding: EdgeInsets.fromLTRB(
        t.space.x4,
        0,
        t.space.x4,
        bottomInset + t.space.x2,
      ),
      child: GlassSurface(
        kind: GlassKind.pill,
        radius: t.radius.fullAll,
        padding: EdgeInsets.symmetric(horizontal: t.space.x3),
        child: SizedBox(
          height: _kTabBarHeight,
          child: Row(
            // Stretch so each cell's tap target fills the full bar height.
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < _kTabs.length; i++)
                Expanded(
                  child: _TabButton(
                    item: _kTabs[i],
                    label: _tabLabel(context, i),
                    selected: tabsRouter.activeIndex == i,
                    onTap: () => tabsRouter.setActiveIndex(i),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.item,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color color = selected ? t.colors.accent : t.colors.textTertiary;
    // Active state stays distinguishable without color alone (WCAG 1.4.1) via a
    // filled icon plus a bolder label weight.
    final TextStyle labelStyle = (selected
            ? t.typography.micro.copyWith(fontWeight: FontWeight.w700)
            : t.typography.micro)
        .copyWith(color: color);
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              selected ? item.activeIcon : item.icon,
              size: _kTabIconSize,
              color: color,
            ),
            SizedBox(height: t.space.x1),
            // Shrink long labels (e.g. "Films & Séries") to fit narrow phones
            // instead of truncating with an ellipsis.
            Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space.x1),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(label, maxLines: 1, style: labelStyle),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
