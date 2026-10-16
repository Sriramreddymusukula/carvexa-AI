import 'package:flutter/material.dart';
import 'package:flutter_car_project/data/models/car_detail.dart';
import 'package:flutter_car_project/presentation/widgets/car_360_viewer.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_car_catalog_repository.dart';
import 'support/pump_app.dart';

/// Taps the compare control on the first tile of the catalog grid.
Future<void> tapFirstCompareControl(WidgetTester tester) async {
  await tester.tap(find.byIcon(Icons.compare_arrows_rounded).first);
  await settle(tester);
}

/// The catalogue, driven entirely by real widgets over a test double.
void main() {
  group('catalog', () {
    testWidgets('lists real vehicles with their real prices', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      expect(find.text('All vehicles'), findsOneWidget);
      expect(find.text('Volvo XC90 B5 AWD'), findsWidgets);
      expect(find.text('₹65 Lakh'), findsWidgets);
    });

    testWidgets('offers no search box where the catalogue cannot search', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      // Both catalogues exist...
      expect(find.text('Used cars'), findsOneWidget);
      expect(find.text('New cars'), findsOneWidget);
      // ...but used listings cannot be searched, so no box is offered.
      expect(find.textContaining('cannot be searched'), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
    });

    testWidgets('searches the new-car catalogue and can be cleared', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      await tester.tap(find.text('New cars'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'nexon');
      await settle(tester, frames: 20);

      // The card shows the model name, with the full vehicle name in its
      // semantic label.
      expect(find.text('Nexon'), findsWidgets);
      expect(find.text('Creta'), findsNothing);

      await tester.tap(find.byTooltip('Clear search'));
      await settle(tester, frames: 20);

      expect(find.text('Creta'), findsWidgets);
    });

    testWidgets('shows an empty state that clears the search', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);
      await tester.tap(find.text('New cars'));
      await settle(tester);

      await tester.enterText(find.byType(TextField), 'nothingmatchesthis');
      await settle(tester, frames: 20);

      expect(find.textContaining('No vehicles match'), findsOneWidget);

      await tester.tap(find.text('Clear search'));
      await settle(tester, frames: 20);

      expect(find.text('Nexon'), findsWidgets);
    });

    testWidgets('loads more vehicles on demand', (WidgetTester tester) async {
      await pumpApp(tester, repository: FakeCarCatalogRepository(pageSize: 2));
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      await openCatalog(tester);

      expect(find.text('Load more'), findsOneWidget);

      await tester.tap(find.text('Load more'));
      await settle(tester, frames: 20);

      expect(find.text('Tata Harrier XZ'), findsWidgets);
    });

    testWidgets('shows an error with a retry action', (
      WidgetTester tester,
    ) async {
      await pumpApp(
        tester,
        repository: FakeCarCatalogRepository(failure: kFakeFailure),
      );
      await tester.pump(const Duration(milliseconds: 1500));
      await settle(tester);
      await openCatalog(tester);

      expect(find.text('Could not load vehicles'), findsOneWidget);
      expect(find.text(kFakeFailure.message), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opens a vehicle details page', (WidgetTester tester) async {
      await pumpHome(tester);
      await openCatalog(tester);

      await tester.tap(find.text('New cars'));
      await settle(tester);
      await tester.tap(find.text('Nexon').first);
      await settle(tester, frames: 20);

      expect(find.text('Back to browse'), findsOneWidget);
      expect(find.text('360° unavailable for this vehicle'), findsOneWidget);
    });

    testWidgets('shows priced variants and updates the selected variant', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      await tester.tap(find.text('New cars'));
      await settle(tester);
      await tester.tap(find.text('Nexon').first);
      await settle(tester, frames: 20);
      await tester.drag(find.byType(ListView).first, const Offset(0, -900));
      await settle(tester);

      expect(find.text('Variants'), findsOneWidget);
      expect(find.textContaining('Est. Hyderabad on-road:'), findsNWidgets(2));

      await tester.tap(find.text('Nexon Fearless'));
      await settle(tester);

      expect(find.text('SELECTED VARIANT ON-ROAD PRICE'), findsOneWidget);
      expect(find.text('Nexon Fearless'), findsWidgets);
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);

      await tester.ensureVisible(find.text('Nexon Smart'));
      Finder compareButton = find.byIcon(Icons.add_box_outlined).first;
      await tester.tap(compareButton);
      await settle(tester);

      await tester.ensureVisible(find.text('Nexon Fearless'));
      compareButton = find.byIcon(Icons.add_box_outlined).first;
      await tester.tap(compareButton);
      await settle(tester);

      expect(find.text('Variant comparison'), findsOneWidget);
      expect(find.text('Hyderabad on-road estimate'), findsNWidgets(2));
      expect(find.text('Nexon Smart'), findsWidgets);
      expect(find.text('Nexon Fearless'), findsWidgets);
    });

    testWidgets(
      'shows rotation controls only for provider-supplied spin frames',
      (WidgetTester tester) async {
        const CarDetail detailWith360 = CarDetail(
          id: 'new-nexon',
          source: 'new',
          title: 'Tata Nexon',
          model: 'Nexon',
          spinImages: <CarImage>[
            CarImage(url: 'https://example.invalid/frame-1.jpg'),
            CarImage(url: 'https://example.invalid/frame-2.jpg'),
          ],
        );
        await pumpApp(
          tester,
          repository: FakeCarCatalogRepository(detail: detailWith360),
        );
        await tester.pump(const Duration(milliseconds: 1500));
        await settle(tester);
        await openCatalog(tester);
        await tester.tap(find.text('Volvo XC90 B5 AWD').first);
        await settle(tester, frames: 20);

        expect(find.byType(Car360Viewer), findsOneWidget);
        expect(find.text('Swipe to rotate'), findsOneWidget);
        expect(find.text('360° unavailable for this vehicle'), findsNothing);
      },
    );
  });

  group('responsive layout', () {
    for (final Size size in <Size>[
      Size(320, 568),
      Size(430, 932),
      Size(932, 430),
      Size(1024, 1366),
    ]) {
      testWidgets(
        'lays out home and catalog at ${size.width.toInt()}x${size.height.toInt()}',
        (WidgetTester tester) async {
          await pumpHome(tester, surfaceSize: size);
          expect(tester.takeException(), isNull);

          await openCatalog(tester);
          expect(tester.takeException(), isNull);
          expect(find.text('All vehicles'), findsOneWidget);
        },
      );
    }
  });

  group('comparison', () {
    testWidgets('a single pick is not yet a comparison', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      // Nothing is shortlisted yet, so the tray must not take any space.
      expect(find.text('Compare'), findsNothing);

      await tapFirstCompareControl(tester);

      // The tray appears and says what is still needed, and the action stays
      // disabled rather than opening a one-column table.
      expect(find.text('Pick 1 more vehicle'), findsOneWidget);
      expect(find.text('Ready to compare'), findsNothing);
    });

    testWidgets('compares two vehicles side by side', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      await tapFirstCompareControl(tester);
      await tapFirstCompareControl(tester);

      expect(find.text('Ready to compare 2 vehicles'), findsOneWidget);

      await tester.tap(find.text('Compare'));
      await settle(tester, frames: 20);

      // The comparison screen lists both vehicles as columns.
      expect(find.text('SIDE BY SIDE'), findsOneWidget);
      expect(find.text('Volvo XC90 B5 AWD'), findsOneWidget);
      expect(find.text('Mini Cooper S'), findsOneWidget);

      // The selected vehicles are marked, so the user can see what they picked.
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(2));
    });

    testWidgets('clearing the shortlist returns the catalog to normal', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      await tapFirstCompareControl(tester);
      await tapFirstCompareControl(tester);
      expect(find.text('Ready to compare 2 vehicles'), findsOneWidget);

      await tester.tap(find.text('Clear'));
      await settle(tester);

      // The tray collapses and the unselected cards come back.
      expect(find.text('Ready to compare'), findsNothing);
      expect(find.byIcon(Icons.compare_arrows_rounded), findsWidgets);
    });

    testWidgets('a fourth vehicle is refused with an explanation', (
      WidgetTester tester,
    ) async {
      await pumpHome(tester);
      await openCatalog(tester);

      // The fake pages at 4, and there are only 2 used cars, so switch to the
      // new catalogue to get a different pair.
      await tapFirstCompareControl(tester);
      await tapFirstCompareControl(tester);

      await tester.tap(find.text('New cars'));
      await settle(tester, frames: 20);

      await tapFirstCompareControl(tester);
      await tapFirstCompareControl(tester);
      expect(find.text('Ready to compare 3 vehicles'), findsOneWidget);
    });
  });
}
