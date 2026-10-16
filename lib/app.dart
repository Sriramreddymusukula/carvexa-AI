import 'package:flutter/material.dart';

import 'core/routing/app_router.dart';
import 'core/theme/app_theme.dart';
import 'di/app_dependencies.dart';

/// Application root.
///
/// Deliberately thin: it wires the dependency graph, hands the router to
/// [MaterialApp.router] and nothing else. All behaviour lives in screens and
/// widgets so this file never becomes a place where logic accumulates.
class CarvexaApp extends StatelessWidget {
  const CarvexaApp({super.key, this.dependencies});

  /// Injected for tests and previews; built by `main` in the running app.
  final AppDependencies? dependencies;

  @override
  Widget build(BuildContext context) {
    final AppDependencies deps = dependencies ?? AppDependencies.production();

    return deps.scope(
      child: MaterialApp.router(
        title: 'Carvexa AI',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark,
        darkTheme: AppTheme.dark,
        themeMode: ThemeMode.dark,
        routerConfig: AppRouter.create(),
        builder: (BuildContext context, Widget? child) {
          // Clamp text scaling to a sane band. Below 1.0 the premium type scale
          // falls apart; above ~1.3 layouts start to overflow, and accessibility
          // guidance is to support up to at least 1.3 rather than beyond.
          final MediaQueryData media = MediaQuery.of(context);
          return MediaQuery(
            data: media.copyWith(
              textScaler: media.textScaler.clamp(
                minScaleFactor: 0.9,
                maxScaleFactor: 1.3,
              ),
            ),
            child: child ?? const SizedBox.shrink(),
          );
        },
      ),
    );
  }
}
