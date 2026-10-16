import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_car_project/app.dart';
import 'package:flutter_car_project/core/routing/app_routes.dart';
import 'package:flutter_car_project/data/repositories/car_catalog_repository.dart';
import 'package:flutter_car_project/di/app_dependencies.dart';

import 'fake_car_catalog_repository.dart';

/// Shared harness for the widget tests.
///
/// Every test runs the **real** app — real router, real controllers, real
/// widgets — with only the catalogue swapped for an in-memory double, so what
/// is verified is the app's own behaviour and not a re-implementation of it.
Future<void> pumpApp(
  WidgetTester tester, {
  Size? surfaceSize,
  CarCatalogRepository? repository,
}) async {
  if (surfaceSize != null) {
    await tester.binding.setSurfaceSize(surfaceSize);
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  await tester.pumpWidget(
    CarvexaApp(
      dependencies: AppDependencies.preview(
        carCatalogRepository: repository ?? FakeCarCatalogRepository(),
      ),
    ),
  );
}

/// Advances frames without [WidgetTester.pumpAndSettle].
///
/// pumpAndSettle cannot be used: the hero showcase has a deliberate, continuous
/// breathing animation, so the tree never goes idle. A bounded number of
/// explicit pumps is the correct tool and is also faster.
Future<void> settle(WidgetTester tester, {int frames = 12}) async {
  for (int i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 80));
  }
}

/// Launches and gets past the splash to a loaded home screen.
Future<void> pumpHome(WidgetTester tester, {Size? surfaceSize}) async {
  await pumpApp(tester, surfaceSize: surfaceSize);
  await tester.pump(const Duration(milliseconds: 1500));
  await settle(tester);
}

/// Switches to the catalogue tab and lets it settle.
Future<void> openCatalog(WidgetTester tester) async {
  await tester.tap(find.text(AppRoutes.catalogLabel));
  await settle(tester);
}
