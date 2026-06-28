import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:iptv_l10n/iptv_l10n.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

const double _kTabBarHeight = 64;

/// Width of the TV side rail (focus-first 10-foot navigation).
const double _kRailWidth = 240;

/// Icon size for the TV side-rail entries.
const double _kRailIconSize = 28;

/// Icon size for the phone bottom-bar tab entries.
const double _kTabIconSize = 24;

/// The tab routes, shared by the phone bottom bar and the TV side rail.
const List<PageRouteInfo<dynamic>> _kTabRoutes = <PageRouteInfo<dynamic>>[
  HomeTabRoute(),
  LiveTabRoute(),
  BrowseTabRoute(),
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

/// 10-foot shell: a persistent focusable side rail beside the tab content.
class _TvShell extends StatelessWidget {
  const _TvShell();

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return AutoTabsRouter(
      routes: _kTabRoutes,
      transitionBuilder: (BuildContext context, Widget child, _) => child,
      builder: (BuildContext context, Widget child) {
        final TabsRouter tabsRouter = AutoTabsRouter.of(context);
        return Scaffold(
          backgroundColor: t.colors.bgBase,
          body: Row(
            children: <Widget>[
              _SideRail(tabsRouter: tabsRouter),
              Expanded(child: child),
            ],
          ),
        );
      },
    );
  }
}

class _SideRail extends StatelessWidget {
  const _SideRail({required this.tabsRouter});

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return FocusTraversalGroup(
      child: Container(
        width: _kRailWidth,
        color: t.colors.bgSurface,
        padding: EdgeInsets.symmetric(
          horizontal: t.space.x3,
          vertical: t.space.x6,
        ),
        child: SafeArea(
          right: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              for (int i = 0; i < _kTabs.length; i++)
                Padding(
                  padding: EdgeInsets.only(bottom: t.space.x2),
                  child: _RailButton(
                    item: _kTabs[i],
                    label: _tabLabel(context, i),
                    selected: tabsRouter.activeIndex == i,
                    // Anchor focus on the active tab when the rail appears.
                    autofocus: tabsRouter.activeIndex == i,
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

class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.item,
    required this.label,
    required this.selected,
    required this.autofocus,
    required this.onTap,
  });

  final _TabItem item;
  final String label;
  final bool selected;
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
          padding: EdgeInsets.symmetric(
            horizontal: t.space.x4,
            vertical: t.space.x3,
          ),
          decoration: BoxDecoration(
            color: selected ? t.colors.accentSubtle : null,
            borderRadius: t.radius.lgAll,
          ),
          child: Row(
            children: <Widget>[
              Icon(
                selected ? item.activeIcon : item.icon,
                size: _kRailIconSize,
                color: color,
              ),
              SizedBox(width: t.space.x3),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: labelStyle,
                ),
              ),
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
  _TabItem(Icons.search_outlined, Icons.search),
  _TabItem(Icons.settings_outlined, Icons.settings),
];

/// Localized label for tab [index] (order matches [_kTabs]).
String _tabLabel(BuildContext context, int index) {
  final AppLocalizations l = AppLocalizations.of(context);
  return <String>[
    l.tabHome,
    l.tabTv,
    l.tabBrowse,
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
