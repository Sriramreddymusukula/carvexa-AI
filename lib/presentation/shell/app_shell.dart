import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/routing/app_routes.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';

/// The persistent application shell: a navigation bar plus the active tab.
///
/// Design decisions for low friction:
///  * Tabs keep their own [Navigator], so switching back to a tab restores
///    where the user was instead of resetting them to the top.
///  * Tapping the active tab pops that tab to its root — the behaviour users
///    expect, and it means there is always a way back to the start of a
///    screen without a back button.
///  * Scroll position is preserved per tab for the same reason.
/// Reads the active tab from the router.
///
/// Taken as a function rather than a field so the shell can never hold a
/// location that has gone stale.
int _indexFor(BuildContext context) {
  final String path = GoRouterState.of(context).uri.path;
  final int index = AppRoutes.tabs.indexOf(path);
  return index < 0 ? 0 : index;
}

/// The persistent application shell: a navigation bar plus the active tab.
///
/// Design decisions for low friction:
///  * Tabs keep their own [Navigator], so switching back to a tab restores
///    where the user was instead of resetting them to the top.
///  * Tapping the active tab pops that tab to its root — the behaviour users
///    expect, and it means there is always a way back to the start of a
///    screen without a back button.
///  * Scroll position is preserved per tab for the same reason.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.child});

  final Widget child;

  void _onDestinationSelected(BuildContext context, int index) {
    if (index == _indexFor(context)) {
      // Re-tapping the current tab returns the user to that tab's root.
      // `maybePop` is a no-op at the root, so this is always safe to call.
      Navigator.of(context).maybePop();
      return;
    }
    context.go(AppRoutes.pathForIndex(index));
  }

  @override
  Widget build(BuildContext context) {
    final int selectedIndex = _indexFor(context);

    return Scaffold(
      body: child,
      extendBody: false,
      bottomNavigationBar: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: context.brand.outline)),
        ),
        child: NavigationBar(
          selectedIndex: selectedIndex,
          onDestinationSelected: (int index) => _onDestinationSelected(context, index),
          destinations: const <Widget>[
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore),
              label: AppRoutes.homeLabel,
              tooltip: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              selectedIcon: Icon(Icons.directions_car),
              label: AppRoutes.catalogLabel,
              tooltip: 'Browse cars',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border),
              selectedIcon: Icon(Icons.favorite),
              label: AppRoutes.favoritesLabel,
              tooltip: 'Saved cars',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: AppRoutes.profileLabel,
              tooltip: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}

/// A minimal top bar used by the shell screens.
///
/// Uses a hairline divider rather than a filled bar so the premium background
/// stays continuous from the top of the screen.
class ShellAppBar extends StatelessWidget {
  const ShellAppBar({super.key, required this.title, this.subtitle, this.trailing, this.overline});

  final String title;
  final String? subtitle;
  final Widget? trailing;
  final String? overline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.lg,
        AppSpacing.pageGutter,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (overline != null) ...<Widget>[
                  Text(
                    overline!.toUpperCase(),
                    style: context.text.labelSmall?.copyWith(
                      color: context.brand.accent,
                      letterSpacing: 1.4,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xxs),
                ],
                Text(
                  title,
                  style: context.text.headlineMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (subtitle != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            // A subtle fade-in so the trailing action settles in with the
            // header rather than appearing fully formed.
            TweenAnimationBuilder<double>(
              tween: Tween<double>(begin: 0, end: 1),
              duration: AppMotion.medium,
              curve: AppMotion.standard,
              builder: (BuildContext context, double value, Widget? child) =>
                  Opacity(opacity: value, child: child),
              child: trailing,
            ),
          ],
        ],
      ),
    );
  }
}
