import "package:auto_route/auto_route.dart";
import "package:flutter/material.dart";
import "package:iptv_ui/iptv_ui.dart";

import "../router.gr.dart";

const double _kTabBarHeight = 56;

/// Main shell with the 5 tabs (spec §3). Color alone marks the active tab.
@RoutePage()
class MainShellScreen extends StatelessWidget {
  const MainShellScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return AutoTabsScaffold(
      backgroundColor: context.appTheme.colors.bgBase,
      routes: const <PageRouteInfo<dynamic>>[
        HomeTabRoute(),
        LiveTabRoute(),
        BrowseTabRoute(),
        SearchTabRoute(),
        SettingsTabRoute(),
      ],
      bottomNavigationBuilder: (BuildContext context, TabsRouter tabsRouter) =>
          _TabBar(tabsRouter: tabsRouter),
    );
  }
}

class _TabItem {
  const _TabItem(this.icon, this.label);
  final IconData icon;
  final String label;
}

const List<_TabItem> _kTabs = <_TabItem>[
  _TabItem(Icons.home_outlined, "Accueil"),
  _TabItem(Icons.live_tv_outlined, "TV"),
  _TabItem(Icons.movie_outlined, "Films & Séries"),
  _TabItem(Icons.search, "Recherche"),
  _TabItem(Icons.settings_outlined, "Réglages"),
];

class _TabBar extends StatelessWidget {
  const _TabBar({required this.tabsRouter});

  final TabsRouter tabsRouter;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    return Container(
      decoration: BoxDecoration(
        color: t.colors.bgSurface,
        border: Border(top: BorderSide(color: t.colors.borderSubtle)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: _kTabBarHeight,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < _kTabs.length; i++)
                Expanded(
                  child: _TabButton(
                    item: _kTabs[i],
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
    required this.selected,
    required this.onTap,
  });

  final _TabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppTheme t = context.appTheme;
    final Color color =
        selected ? t.colors.accent : t.colors.textTertiary;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(item.icon, size: 24, color: color),
          SizedBox(height: t.space.x1),
          // Shrink long labels (e.g. "Films & Séries") to fit narrow phones
          // instead of truncating with an ellipsis.
          Padding(
            padding: EdgeInsets.symmetric(horizontal: t.space.x1),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                item.label,
                maxLines: 1,
                style: t.typography.micro.copyWith(color: color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
