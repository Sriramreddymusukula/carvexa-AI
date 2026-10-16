import 'package:flutter_test/flutter_test.dart';

import 'package:flutter_car_project/core/utils/view_state.dart';
import 'package:flutter_car_project/data/models/car_preview.dart';
import 'package:flutter_car_project/presentation/state/catalog_controller.dart';
import 'package:flutter_car_project/presentation/state/compare_controller.dart';

import 'support/fake_car_catalog_repository.dart';

void main() {
  group('sellerLabel', () {
    test('joins the published owner and city for a used listing', () {
      expect(kUsedVolvo.sellerLabel, 'First owner  ·  Gurgaon');
    });

    test('is null for a new car, which has no seller', () {
      // A new-car listing is not sold by an individual, so attaching an owner
      // would be a claim the catalogue never made.
      expect(kNewNexon.isUsed, isFalse);
      expect(kNewNexon.sellerLabel, isNull);
    });

    test('is null when the catalogue published no seller information', () {
      const CarPreview anonymous = CarPreview(
        id: 'used-anonymous',
        title: 'Unattributed listing',
        model: 'Unattributed',
        source: 'used',
      );

      // "Owner unknown" is an assertion, not a fact. Show nothing instead.
      expect(anonymous.isUsed, isTrue);
      expect(anonymous.sellerLabel, isNull);
    });

    test('shows whichever half the catalogue actually published', () {
      const CarPreview ownerOnly = CarPreview(
        id: 'used-owner-only',
        title: 'Owner only',
        model: 'Owner only',
        source: 'used',
        owner: 'Second owner',
      );
      const CarPreview cityOnly = CarPreview(
        id: 'used-city-only',
        title: 'City only',
        model: 'City only',
        source: 'used',
        city: 'Pune',
      );

      expect(ownerOnly.sellerLabel, 'Second owner');
      expect(cityOnly.sellerLabel, 'Pune');
    });
  });

  group('source switching', () {
    // The original bug: the tab and the header moved to the new source the
    // instant they were tapped, while the list kept showing the previous
    // source's cars until the slow request came back. To a user that reads as
    // "the catalogue is inverted" - tap New cars, see used cars.
    test('never leaves the previous source on screen while switching', () async {
      final FakeCarCatalogRepository repository = FakeCarCatalogRepository(
        latency: const Duration(milliseconds: 80),
      );
      final CatalogController controller = CatalogController(
        repository: repository,
        debounce: Duration.zero,
      );

      await controller.start();
      expect(controller.snapshot.state, ViewState.data);
      expect(
        controller.snapshot.data!.cars.every((CarPreview c) => c.source == 'used'),
        isTrue,
      );

      // Switch sources and look at the screen *before* the new results land.
      // `setSource` kicks off an unawaited load, so the pending call is tracked
      // here purely so the test can await the same request before asserting.
      controller.setSource('new');

      expect(controller.query.source, 'new');
      // The header already says "new", so the list must not still be showing
      // used cars. Either the old results are dropped (data is null) or they are
      // already the new source's. Any surviving used car is the bug.
      expect(
        controller.snapshot.data?.cars.any((CarPreview c) => c.source != 'new') ?? false,
        isFalse,
        reason: 'used cars stayed on screen after switching to the new catalogue',
      );
      expect(controller.snapshot.state, isNot(ViewState.data));

      // The slow request finally lands, and now the new cars are correct.
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(controller.snapshot.state, ViewState.data);
      expect(
        controller.snapshot.data!.cars.every((CarPreview c) => c.source == 'new'),
        isTrue,
      );
    });

    test('keeps results visible for a same-query refresh', () async {
      final FakeCarCatalogRepository repository = FakeCarCatalogRepository(
        latency: const Duration(milliseconds: 40),
      );
      final CatalogController controller = CatalogController(
        repository: repository,
        debounce: Duration.zero,
      );

      await controller.start();
      final int before = repository.calls.length;

      // Pull-to-refresh asks the same question again, so the list must not blink
      // out to a skeleton. That is the whole difference between a refresh and a
      // source change.
      final Future<void> refreshing = controller.load(force: true);
      expect(repository.calls.length, before + 1);
      expect(controller.snapshot.state, ViewState.data);
      expect(controller.snapshot.hasData, isTrue);

      await refreshing;
    });
  });

  group('CompareController', () {
    late CompareController compare;

    setUp(() => compare = CompareController());

    test('starts empty', () {
      expect(compare.isEmpty, isTrue);
      expect(compare.selected, isEmpty);
      expect(compare.canCompare, isFalse);
    });

    test('one vehicle is not a comparison', () {
      expect(compare.toggle(kUsedVolvo), isTrue);

      expect(compare.selected, hasLength(1));
      expect(compare.contains(kUsedVolvo.id), isTrue);
      // A single column is just a details page, so the action stays disabled.
      expect(compare.canCompare, isFalse);
    });

    test('two vehicles are enough to compare', () {
      compare.toggle(kUsedVolvo);
      compare.toggle(kNewNexon);

      expect(compare.canCompare, isTrue);
      // Insertion order is the column order on the comparison screen.
      expect(compare.selected.map((c) => c.id), <String>[
        kUsedVolvo.id,
        kNewNexon.id,
      ]);
    });

    test('refuses a fourth vehicle instead of silently dropping one', () {
      final List<CarPreview> four = <CarPreview>[
        kUsedVolvo,
        kUsedMini,
        kNewNexon,
        kNewCreta,
      ];
      for (final CarPreview car in four.take(3)) {
        expect(compare.toggle(car), isTrue);
      }

      // The refusal must be reported so the caller can explain it.
      expect(compare.toggle(four.last), isFalse);
      expect(compare.selected, hasLength(CompareController.maxVehicles));
      // The rejected vehicle is simply absent, not swapped in.
      expect(compare.contains(four.last.id), isFalse);
    });

    test('toggling a selected vehicle removes it', () {
      compare.toggle(kUsedVolvo);
      compare.toggle(kNewNexon);

      expect(compare.toggle(kUsedVolvo), isTrue);

      expect(compare.contains(kUsedVolvo.id), isFalse);
      expect(compare.selected, hasLength(1));
    });

    test('a full shortlist still accepts removing a member', () {
      compare.toggle(kUsedVolvo);
      compare.toggle(kUsedMini);
      compare.toggle(kNewNexon);

      // Removal must never be blocked by the limit, or a full shortlist would
      // be impossible to get out of.
      expect(compare.toggle(kUsedMini), isTrue);
      expect(compare.selected, hasLength(2));
    });

    test('remove is a no-op for a vehicle that is not on the list', () {
      compare.toggle(kUsedVolvo);

      int notifications = 0;
      compare.addListener(() => notifications++);

      compare.remove(kNewNexon.id);

      // No state change, so no notification.
      expect(notifications, isZero);
      expect(compare.selected, hasLength(1));
    });

    test('clear empties the shortlist and notifies once', () {
      compare.toggle(kUsedVolvo);
      compare.toggle(kNewNexon);

      int notifications = 0;
      compare.addListener(() => notifications++);

      compare.clear();

      expect(compare.isEmpty, isTrue);
      expect(notifications, 1);
    });

    test('selected is unmodifiable, so the list cannot be edited behind it', () {
      compare.toggle(kUsedVolvo);

      expect(
        () => compare.selected.add(kNewNexon),
        throwsUnsupportedError,
      );
    });
  });
}
