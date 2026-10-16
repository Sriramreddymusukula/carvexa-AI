import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';

import '../core/config/app_config.dart';
import '../core/network/api_client.dart';
import '../data/repositories/car_catalog_repository.dart';
import '../presentation/state/account_controller.dart';
import '../presentation/state/compare_controller.dart';
import '../presentation/state/favorites_controller.dart';
import '../presentation/state/home_feed_controller.dart';

/// Composition root.
///
/// The single place where concrete implementations are chosen. Everything
/// else depends on interfaces, keeping production and test implementations
/// replaceable without coupling screens to either one.
class AppDependencies {
  const AppDependencies._({
    required this.config,
    required this.apiClient,
    required this.carCatalogRepository,
    required this.sessionStore,
  });

  final AppConfig config;
  final ApiClient apiClient;
  final CarCatalogRepository carCatalogRepository;
  final SessionStore sessionStore;

  /// Builds the graph for a running app.
  ///
  /// Production binds [RemoteCarCatalogRepository], the catalog transport used
  /// by the running application.
  factory AppDependencies.production() {
    final AppConfig config = AppConfig.fromEnvironment();
    final ApiClient apiClient = ApiClient(config: config);

    return AppDependencies._(
      config: config,
      apiClient: apiClient,
      carCatalogRepository: RemoteCarCatalogRepository(apiClient: apiClient),
      sessionStore: const SecureSessionStore(),
    );
  }

  /// Builds a graph with injected doubles, for tests and previews.
  ///
  /// Defaults to the real repository, so a preview without an override behaves
  /// like the app. Tests pass their own double.
  factory AppDependencies.preview({
    AppConfig? config,
    ApiClient? apiClient,
    CarCatalogRepository? carCatalogRepository,
    SessionStore? sessionStore,
  }) {
    final AppConfig resolvedConfig = config ?? AppConfig.fromEnvironment();
    final ApiClient resolvedApi = apiClient ?? ApiClient(config: resolvedConfig);

    return AppDependencies._(
      config: resolvedConfig,
      apiClient: resolvedApi,
      carCatalogRepository:
          carCatalogRepository ?? RemoteCarCatalogRepository(apiClient: resolvedApi),
      sessionStore: sessionStore ?? MemorySessionStore(),
    );
  }

  /// Provides everything the widget tree needs.
  ///
  /// [Provider] owns the app-scoped and screen-scoped state objects; the
  /// composition root keeps their lifetimes explicit.
  Widget scope({required Widget child}) {
    return MultiProvider(
      providers: <SingleChildWidget>[
        Provider<AppConfig>.value(value: config),
        Provider<ApiClient>.value(value: apiClient),
        Provider<CarCatalogRepository>.value(value: carCatalogRepository),
        ChangeNotifierProvider<AccountController>(
          create: (_) => AccountController(apiClient: apiClient, sessionStore: sessionStore)
            ..restoreSession(),
        ),
        ChangeNotifierProxyProvider<AccountController, FavoritesController>(
          create: (_) => FavoritesController(apiClient: apiClient),
          update: (_, AccountController account, FavoritesController? favorites) =>
              favorites!..syncAuthentication(account),
        ),
        ChangeNotifierProvider<HomeFeedController>(
          create: (_) => HomeFeedController(repository: carCatalogRepository),
        ),
        // App-scoped, not screen-scoped: a shortlist the user builds in the
        // catalogue has to still be there when they reach for it from Home.
        ChangeNotifierProvider<CompareController>(create: (_) => CompareController()),
      ],
      child: child,
    );
  }
}
