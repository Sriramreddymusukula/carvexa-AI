import 'package:flutter/material.dart';
import 'package:flutter_car_project/core/theme/app_theme.dart';
import 'package:flutter_car_project/data/models/hyderabad_price_estimate.dart';
import 'package:flutter_car_project/presentation/widgets/on_road_price_tooltip.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows the Hyderabad price breakdown when tapped on mobile', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(360, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final HyderabadPriceEstimate estimate = HyderabadPriceEstimate.forNewCar(
      price: 1000000,
      priceLabel: '10 Lakh',
    )!;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: OnRoadPriceTooltip(
              estimate: estimate,
              child: const Text('₹12.15 Lakh'),
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.expand_more), findsOneWidget);
    await tester.tap(find.text('₹12.15 Lakh'));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.keyboard_arrow_up), findsOneWidget);
    expect(find.text('Hyderabad on-road estimate'), findsOneWidget);
    expect(find.text('Ex-showroom (GST included)'), findsOneWidget);
    expect(find.text('Telangana life tax / RTO (18%)'), findsOneWidget);
    expect(find.text('Insurance estimate'), findsOneWidget);
    expect(find.text('Road-safety cess'), findsOneWidget);
    expect(find.text('Estimated on-road total'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
