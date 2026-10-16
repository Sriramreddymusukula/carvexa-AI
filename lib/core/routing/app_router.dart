import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../presentation/motion/road_page_route.dart';
import '../../presentation/screens/car_details/car_details_screen.dart';
import '../../presentation/screens/ai/ai_assistant_screen.dart';
import '../../presentation/screens/catalog/catalog_screen.dart';
import '../../presentation/screens/compare/compare_screen.dart';
import '../../presentation/screens/favorites/favorites_screen.dart';
import '../../presentation/screens/home/home_screen.dart';
import '../../presentation/screens/profile/profile_screen.dart';
import '../../presentation/screens/splash/splash_screen.dart';
import 'app_routes.dart';

/// Keeps tab navigation state while routing detail and task screens above the shell.
abstract final class AppRouter {
  /// Keys are created **per router instance**, not as statics.
  ///
  /// A static `GlobalKey` would be handed to the next `create()` call as well -
  /// which happens in every test, and on a hot restart - and Flutter rejects a
  /// `GlobalKey` that appears more than once in a tree. Owning them for the
  /// lifetime of one router is both correct and free.
  static GoRouter create() {
    final GlobalKey<NavigatorState> rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
    final Map<String, GlobalKey<NavigatorState>> shellKeys =
        <String, GlobalKey<NavigatorState>>{
          for (final String path in AppRoutes.tabs)
            path: GlobalKey<NavigatorState>(debugLabel: path),
        };

    return GoRouter(
      navigatorKey: rootKey,
      initialLocation: AppRoutes.splash,
      debugLogDiagnostics: false,
      routes: <RouteBase>[
        GoRoute(
          path: AppRoutes.splash,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _fade(state, const SplashScreen()),
        ),
        // Pushed above the shell so a details page is immersive: no navigation
        // bar competing with the hero image, and one back gesture returns to
        // exactly the list the user came from.
        GoRoute(
          path: AppRoutes.carDetailPattern,
          pageBuilder: (BuildContext context, GoRouterState state) => _road(
            state,
            CarDetailsScreen(carId: state.pathParameters['id'] ?? ''),
          ),
        ),
        // The comparison is a full-screen task, so it is immersive for the same
        // reason: the whole point is a wide table with nothing competing for it.
        GoRoute(
          path: AppRoutes.compare,
          pageBuilder: (BuildContext context, GoRouterState state) =>
              _road(state, const CompareScreen()),
        ),
        GoRoute(
          path: AppRoutes.ai,
          pageBuilder: (BuildContext context, GoRouterState state) => _road(
            state,
            AiAssistantScreen(
              initialVehicleIds: state.extra is String ? <String>[state.extra! as String] : const <String>[],
            ),
          ),
        ),
        for (final String path in AppRoutes.tabs)
          ShellRoute(
            navigatorKey: shellKeys[path],
            builder: (BuildContext context, GoRouterState state, Widget? child) =>
                child ?? const SizedBox.shrink(),
            routes: <RouteBase>[
              GoRoute(
                path: path,
                pageBuilder: (BuildContext context, GoRouterState state) => _road(
                  state,
                  _screenFor(path, state),
                ),
              ),
            ],
          ),
      ],
      errorBuilder: (BuildContext context, GoRouterState state) =>
          _RouteErrorScreen(location: state.uri.toString()),
    );
  }

  /// Builds the screen for a tab.
  ///
  /// The catalogue reads its optional `focus=search` / `q=` parameters from the
  /// location here rather than from its own build, because asking a route for
  /// its state from inside a provider's `create` registers a dependency in a
  /// lifecycle that is never rebuilt.
  static Widget _screenFor(String path, GoRouterState state) => switch (path) {
    AppRoutes.home => const HomeScreen(),
    AppRoutes.catalog => CatalogScreen(
      focusSearch: state.uri.queryParameters['focus'] == 'search',
      initialQuery: state.uri.queryParameters['q'],
    ),
    AppRoutes.favorites => const FavoritesScreen(),
    AppRoutes.profile => const ProfileScreen(),
    _ => const HomeScreen(),
  };

  // ---------------------------------------------------------------------------

  /// Tab switches use the road transition: short, directional, automotive.
  static CustomTransitionPage<void> _road(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 260),
      reverseTransitionDuration: const Duration(milliseconds: 200),
      transitionsBuilder: roadTransitions(false),
    );
  }

  /// The splash fades the app in rather than sliding it.
  static CustomTransitionPage<void> _fade(GoRouterState state, Widget child) {
    return CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 420),
      transitionsBuilder:
          (
            BuildContext context,
            Animation<double> animation,
            Animation<double> secondary,
            Widget page,
          ) => FadeTransition(opacity: animation, child: page),
    );
  }
}

/// Shown when a route cannot be matched. Kept on-brand rather than dumping the
/// framework's red error page at a user.
class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.location});

  final String location;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                const Icon(Icons.explore_off_outlined, size: 48),
                const SizedBox(height: 16),
                Text('That screen does not exist', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text(
                  location,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: () => context.go(AppRoutes.home),
                  child: const Text('Go to home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
