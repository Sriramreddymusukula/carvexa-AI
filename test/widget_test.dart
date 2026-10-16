import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_car_project/core/theme/app_theme.dart';
import 'package:flutter_car_project/presentation/motion/pressable_scale.dart';
import 'package:flutter_car_project/presentation/screens/home/home_search_entry.dart';
import 'package:flutter_car_project/presentation/widgets/state_views.dart';

import 'support/pump_app.dart';

void main() {
  group('application shell', () {
    testWidgets('launches the splash screen, not the default counter app', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester);
      await tester.pump();

      expect(find.text('CARVEXA'), findsOneWidget);
      expect(find.text('You have pushed the button this many times:'), findsNothing);
    });

    testWidgets('reaches the home screen after the splash', (WidgetTester tester) async {
      await pumpHome(tester);

      expect(find.text('Find your next car'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    });
  });

  group('home', () {
    testWidgets('leads with new cars, not the used catalogue', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);

      // Home is the shop window, so it shows what you can buy new. The backend's
      // own default source is 'used'; asking for the default would put second-hand
      // listings on the front page, so the controller resolves the searchable
      // source instead.
      expect(find.text('Tata Nexon'), findsWidgets);
      // The home feed labels itself from the source it actually loaded.
      expect(find.text('New cars from the live catalogue'), findsOneWidget);
      expect(find.text('Used cars from the live catalogue'), findsNothing);

      // The used catalogue is one tap away in the catalog, not the home page.
      expect(find.text('Volvo XC90 B5 AWD'), findsNothing);
      // Live inventory must never be labelled as sample content.
      expect(find.text('Sample data'), findsNothing);
    });

    testWidgets('shows a seller for a used listing but never invents one', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      // The catalog defaults to the catalogue's own default source, which is the
      // used listings, so the real Volvo should be on screen.
      expect(find.text('Volvo XC90 B5 AWD'), findsWidgets);

      // owner + city are published by the API, so both are shown.
      expect(find.textContaining('First owner'), findsWidgets);
      expect(find.textContaining('Gurgaon'), findsWidgets);
    });

    testWidgets('opens search from the home entry point', (WidgetTester tester) async {
      await pumpHome(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(HomeSearchEntry),
          matching: find.byType(PressableScale),
        ),
      );
      await settle(tester);

      expect(find.text('All vehicles'), findsOneWidget);
    });
  });

  group('state views', () {
    testWidgets('error state offers a retry and hides technical detail', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: ErrorState(
              title: 'Could not load',
              message: 'Check your connection.',
              debugDetail: 'SocketException: 192.168.137.135:4000 (never displayed)',
              onRetry: () {},
            ),
          ),
        ),
      );

      expect(find.text('Try again'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });
  });
}

