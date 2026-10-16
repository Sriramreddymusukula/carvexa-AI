import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/car_detail.dart';
import '../../../data/models/car_preview.dart';
import '../../../data/repositories/car_catalog_repository.dart';
import '../../state/compare_controller.dart';
import '../../widgets/automotive_image.dart';
import '../../widgets/automotive_loader.dart';
import '../../widgets/state_views.dart';
import '../../widgets/vehicle_silhouette.dart';

/// Side-by-side comparison of the vehicles on the shortlist.
///
/// The rule this screen exists to keep: **every value shown was published by
/// the catalogue for that vehicle.** A cell the catalogue did not publish reads
/// "Not published" - never a blank, a zero, or a plausible-looking guess.
/// Comparing invented numbers would be worse than not comparing at all.
///
/// Each vehicle's full detail is fetched rather than reusing the card summary,
/// because a comparison is only worth opening when it reaches the engine and
/// specification data the list view leaves out.
class CompareScreen extends StatefulWidget {
  const CompareScreen({super.key});

  @override
  State<CompareScreen> createState() => _CompareScreenState();
}

class _CompareScreenState extends State<CompareScreen> {
  Map<String, CarDetail> _details = <String, CarDetail>{};
  Set<String> _failed = <String>{};

  /// Ids currently being fetched, so a column can show its own progress.
  List<String> _wanted = <String>[];

  @override
  void initState() {
    super.initState();
    // Deferred one frame for the same reason the home screen defers its load:
    // setting state during the first build would mark a provider dirty while
    // the framework is still building.
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  /// Loads detail for anything on the shortlist we do not already have.
  Future<void> _sync() async {
    if (!mounted) return;

    final List<String> wanted = context
        .read<CompareController>()
        .selected
        .map((CarPreview car) => car.id)
        .where((String id) => !_details.containsKey(id))
        .toList(growable: false);

    if (wanted.isEmpty) return;

    setState(() => _wanted = wanted);

    // One request per vehicle, in parallel: a comparison is only as fast as its
    // slowest column, and there are never more than three.
    await Future.wait(
      wanted.map((String id) async {
        try {
          final CarDetail detail = await context
              .read<CarCatalogRepository>()
              .fetchCar(id);
          if (!mounted) return;
          setState(() {
            _details = <String, CarDetail>{..._details, id: detail};
            _failed = <String>{..._failed}..remove(id);
            _wanted = <String>[..._wanted]..remove(id);
          });
        } catch (_) {
          if (!mounted) return;
          setState(() {
            _failed = <String>{..._failed, id};
            _wanted = <String>[..._wanted]..remove(id);
          });
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    final CompareController compare = context.watch<CompareController>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(count: compare.selected.length, onClear: compare.clear),
            Expanded(
              child: compare.selected.length < 2
                  ? _NotEnough(remaining: 2 - compare.selected.length)
                  : _Comparison(
                      cars: compare.selected,
                      details: _details,
                      failed: _failed,
                      wanted: _wanted,
                      onRemove: compare.remove,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.count, required this.onClear});

  final int count;
  final VoidCallback onClear;

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
        children: <Widget>[
          _IconAction(
            icon: Icons.arrow_back_rounded,
            tooltip: 'Back',
            onPressed: () => context.pop(),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'COMPARE',
                  style: context.text.labelSmall?.copyWith(
                    color: context.brand.accent,
                    letterSpacing: 1.4,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text('SIDE BY SIDE', style: context.text.headlineMedium),
              ],
            ),
          ),
          if (count > 0)
            TextButton(
              onPressed: onClear,
              child: Text('Clear', style: context.text.labelMedium),
            ),
        ],
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({required this.icon, required this.tooltip, required this.onPressed});

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: context.brand.surfaceRaised,
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(icon, size: 20, color: context.brand.textPrimary),
          ),
        ),
      ),
    );
  }
}

/// Fewer than two vehicles: a comparison needs something to compare against.
class _NotEnough extends StatelessWidget {
  const _NotEnough({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      title: 'Pick $remaining more ${remaining == 1 ? 'vehicle' : 'vehicles'}',
      message:
          'Tap the compare icon on any vehicle to add it here. Two or more can '
          'then be read side by side.',
      icon: Icons.compare_arrows_rounded,
      actionLabel: 'Back to browse',
      onAction: () => context.pop(),
    );
  }
}


/// The comparison table.
class _Comparison extends StatelessWidget {
  const _Comparison({
    required this.cars,
    required this.details,
    required this.failed,
    required this.wanted,
    required this.onRemove,
  });

  final List<CarPreview> cars;
  final Map<String, CarDetail> details;
  final Set<String> failed;
  final List<String> wanted;
  final ValueChanged<String> onRemove;

  static const double _labelWidth = 92;
  static const double _columnWidth = 152;
  static const double _rowHeight = 44;

  @override
  Widget build(BuildContext context) {
    final List<_Row> rows = _buildRows();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (wanted.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                const AutomotiveLoader(size: 16, strokeWidth: 1.6),
                const SizedBox(width: AppSpacing.sm),
                Text('Loading full details', style: context.text.bodySmall),
              ],
            ),
          ),
        Expanded(
          // One horizontal scroll around the whole table, so the vehicle headers
          // and their figures can never drift out of alignment.
          child: SingleChildScrollView(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.pageGutter),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    _vehicleHeaders(context),
                    const SizedBox(height: AppSpacing.sm),
                    for (final _Row row in rows) _dataRow(context, row),
                    const SizedBox(height: AppSpacing.xxl),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _vehicleHeaders(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: _labelWidth,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: Text(
              'VEHICLE',
              style: context.text.labelSmall?.copyWith(fontSize: 8.5),
            ),
          ),
        ),
        for (final CarPreview car in cars)
          SizedBox(
            width: _columnWidth,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              child: _VehicleHeader(
                car: car,
                loading: wanted.contains(car.id),
                failed: failed.contains(car.id),
                onRemove: () => onRemove(car.id),
                onOpen: car.detailAvailable
                    ? () => context.push(AppRoutes.carDetails(car.id))
                    : null,
              ),
            ),
          ),
      ],
    );
  }


  Widget _dataRow(BuildContext context, _Row row) {
    return Container(
      height: _rowHeight,
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: context.brand.outline.withValues(alpha: 0.6)),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          SizedBox(
            width: _labelWidth,
            child: Padding(
              padding: const EdgeInsets.only(right: AppSpacing.sm),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  row.label,
                  maxLines: 2,
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 9.5,
                    color: context.brand.textTertiary,
                  ),
                ),
              ),
            ),
          ),
          for (int i = 0; i < cars.length; i++)
            SizedBox(
              width: _columnWidth,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    row.values[i] ?? 'Not published',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: row.values[i] == null
                        ? context.text.bodySmall?.copyWith(
                            color: context.brand.textTertiary,
                            fontStyle: FontStyle.italic,
                          )
                        : context.text.bodyMedium,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// The union of everything the catalogue published about these vehicles.
  ///
  /// Rows nobody can answer are dropped rather than rendered as a column of
  /// "not published", and a value one vehicle has and another does not shows the
  /// gap honestly instead of hiding the row.
  List<_Row> _buildRows() {
    final List<String> labels = <String>[];
    for (final CarPreview car in cars) {
      for (final CarSpecRow fact in _factsFor(car)) {
        if (!labels.contains(fact.label)) labels.add(fact.label);
      }
    }

    final List<_Row> rows = <_Row>[];

    // Price leads: it is the first thing anyone compares, and the detail model
    // keeps it out of `keyFacts` because the details page renders it separately.
    final List<String?> prices = <String?>[
      for (final CarPreview car in cars)
        car.priceAvailable ? car.formattedPrice : null,
    ];
    if (prices.any((String? value) => value != null)) {
      rows.add(_Row('Price', prices));
    }

    for (final String label in labels) {
      final List<String?> values = <String?>[
        for (final CarPreview car in cars) _valueFor(car, label),
      ];
      if (values.every((String? value) => value == null)) continue;
      rows.add(_Row(label, values));
    }

    return rows;
  }

  /// Falls back to the card summary while the full detail is still in flight, so
  /// the table is useful immediately instead of blank.
  List<CarSpecRow> _factsFor(CarPreview car) {
    final CarDetail? detail = details[car.id];
    if (detail == null) {
      return car.specs
          .map((CarSpec spec) => CarSpecRow(label: spec.label, value: spec.value))
          .toList(growable: false);
    }
    return <CarSpecRow>[
      ...detail.keyFacts,
      ...detail.engineSpecs,
      ...detail.dimensions,
      for (final CarSpecSection section in detail.specificationSections) ...section.items,
      if (detail.features.isNotEmpty)
        CarSpecRow(label: 'Features', value: detail.features.join(', ')),
    ];
  }

  String? _valueFor(CarPreview car, String label) {
    for (final CarSpecRow fact in _factsFor(car)) {
      if (fact.label == label) return fact.value;
    }
    return null;
  }
}

/// One comparison line: a label and one value per vehicle (null = not published).
class _Row {
  const _Row(this.label, this.values);

  final String label;
  final List<String?> values;
}


class _VehicleHeader extends StatelessWidget {
  const _VehicleHeader({
    required this.car,
    required this.loading,
    required this.failed,
    required this.onRemove,
    required this.onOpen,
  });

  final CarPreview car;
  final bool loading;
  final bool failed;
  final VoidCallback onRemove;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Stack(
            children: <Widget>[
              AutomotiveImage(
                imageUrl: car.imageUrl,
                aspectRatio: AutomotiveImageRatio.tile,
                semanticLabel: '${car.displayName} image',
              ),
              if (loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(child: AutomotiveLoader(size: 20, strokeWidth: 1.6)),
                  ),
                ),
              if (failed && !loading)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Color(0x66000000),
                    child: Center(
                      child: Icon(
                        Icons.cloud_off_rounded,
                        size: 20,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              Positioned(
                top: 2,
                right: 2,
                child: IconButton(
                  onPressed: onRemove,
                  tooltip: 'Remove from comparison',
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.black.withValues(alpha: 0.62),
                    foregroundColor: context.brand.accentBright,
                  ),
                  icon: const Icon(Icons.check_rounded, size: 18),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            car.sourceLabel.toUpperCase(),
            style: context.text.labelSmall?.copyWith(
              color: context.brand.accent,
              fontSize: 8.5,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            car.displayName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall,
          ),
        ],
      ),
    );
  }
}

