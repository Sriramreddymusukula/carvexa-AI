import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app.dart';
import 'di/app_dependencies.dart';

/// Application entry point.
///
/// The default counter demo that shipped with the template is gone: the app
/// now boots straight into the Carvexa AI shell.
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // A dark, edge-to-edge surface: the premium identity is dark-first.
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Color(0xFF0B0C0E),
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );

  SystemChrome.setEnabledSystemUIMode(
    SystemUiMode.edgeToEdge,
  );

  runApp(CarvexaApp(dependencies: AppDependencies.production()));
}
