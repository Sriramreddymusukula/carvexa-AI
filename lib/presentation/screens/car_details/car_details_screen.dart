import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/network/api_client.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/view_state.dart';
import '../../../data/models/car_detail.dart';
import '../../../data/models/car_preview.dart';
import '../../../data/models/hyderabad_price_estimate.dart';
import '../../../data/repositories/car_catalog_repository.dart';
import '../../motion/drive_in_reveal.dart';
import '../../state/account_controller.dart';
import '../../state/car_details_controller.dart';
import '../../state/compare_controller.dart';
import '../../widgets/car_gallery.dart';
import '../../widgets/car_360_viewer.dart';
import '../../widgets/favorite_action.dart';
import '../../widgets/loading_skeleton.dart';
import '../../widgets/on_road_price_tooltip.dart';
import '../../widgets/premium_button.dart';
import '../../widgets/state_views.dart';
import '../../widgets/vehicle_emi_calculator.dart';

/// One vehicle's details page.
///
/// Everything on it comes from the catalogue: the gallery is real photography,
/// the price is the published price (or an honest "price on request"), and any
/// section the catalogue did not publish is simply absent rather than filled
/// with a plausible-looking placeholder.
class CarDetailsScreen extends StatelessWidget {
  const CarDetailsScreen({super.key, required this.carId});

  /// Opaque id minted by our backend.
  final String carId;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<CarDetailsController>(
      create: (BuildContext context) => CarDetailsController(
        repository: context.read<CarCatalogRepository>(),
        carId: carId,
      )..load(),
      child: const _CarDetailsView(),
    );
  }
}

class _CarDetailsView extends StatelessWidget {
  const _CarDetailsView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Consumer<CarDetailsController>(
          builder: (BuildContext context, CarDetailsController controller, _) {
            switch (controller.snapshot.state) {
              case ViewState.initial:
              case ViewState.loading:
                return const _DetailsSkeleton();

              case ViewState.error:
                return ErrorState.fromFailure(
                  title: 'Could not load this vehicle',
                  failure: controller.snapshot.failure!,
                  onRetry: controller.retry,
                );

              case ViewState.empty:
              case ViewState.data:
                final CarDetail? car = controller.snapshot.data;
                if (car == null) return const _DetailsSkeleton();
                return _DetailsContent(car: car);
            }
          },
        ),
      ),
    );
  }
}

class _DetailsContent extends StatefulWidget {
  const _DetailsContent({required this.car});

  final CarDetail car;

  @override
  State<_DetailsContent> createState() => _DetailsContentState();
}

class _DetailsContentState extends State<_DetailsContent> {
  CarVariant? _selectedVariant;
  final List<CarVariant> _variantsToCompare = <CarVariant>[];

  void _toggleVariantComparison(CarVariant variant) {
    setState(() {
      if (_variantsToCompare.any(
        (CarVariant item) => identical(item, variant),
      )) {
        _variantsToCompare.removeWhere(
          (CarVariant item) => identical(item, variant),
        );
      } else if (_variantsToCompare.length < 2) {
        _variantsToCompare.add(variant);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final CarDetail car = widget.car;
    return Stack(
      children: <Widget>[
        ListView(
          padding: EdgeInsets.zero,
          children: <Widget>[
            CarGallery(images: car.images, heroUrl: car.title),
            Car360Viewer(frames: car.spinImages),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.pageGutter,
                AppSpacing.xl,
                AppSpacing.pageGutter,
                AppSpacing.xxxl,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _Title(car: car),
                  if (car.catalogOrigin == 'local_demo') ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    const _SampleDataNotice(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _PriceBlock(car: car, selectedVariant: _selectedVariant),
                  if (car.source == 'new') ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    if (car.variants.isNotEmpty)
                      _Variants(
                        car: car,
                        selectedVariant: _selectedVariant,
                        variantsToCompare: _variantsToCompare,
                        onSelected: (CarVariant variant) => setState(
                          () => _selectedVariant =
                              identical(_selectedVariant, variant)
                              ? null
                              : variant,
                        ),
                        onCompareToggle: _toggleVariantComparison,
                        onClearComparison: () =>
                            setState(_variantsToCompare.clear),
                      )
                    else
                      const _VariantsUnavailable(),
                  ],
                  const SizedBox(height: AppSpacing.lg),
                  _VehicleActions(car: car),
                  if (car.keyFacts.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xl),
                    _KeyFacts(facts: car.keyFacts),
                  ],
                  if (car.overview.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    _SpecSection(
                      title: car.source == 'used'
                          ? 'Listing details'
                          : 'Details',
                      items: car.overview,
                    ),
                  ],
                  if (car.engineSpecs.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    _SpecSection(
                      title: 'Engine & performance',
                      items: car.engineSpecs,
                    ),
                  ],
                  if (car.dimensions.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    _SpecSection(title: 'Dimensions', items: car.dimensions),
                  ],
                  for (final CarSpecSection section
                      in car.specificationSections) ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    _SpecSection(title: section.title, items: section.items),
                  ],
                  if (car.features.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.sectionGap),
                    _Features(car: car),
                  ],
                  const SizedBox(height: AppSpacing.xxxl),
                  Center(
                    child: PremiumButton(
                      label: 'Back to browse',
                      variant: PremiumButtonVariant.secondary,
                      icon: Icons.arrow_back_rounded,
                      onPressed: () => context.pop(),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        // Floating back control, so the gallery can own the full width.
        Positioned(
          top: AppSpacing.sm,
          left: AppSpacing.sm,
          child: _BackButton(onPressed: () => context.pop()),
        ),
      ],
    );
  }
}

class _VehicleActions extends StatefulWidget {
  const _VehicleActions({required this.car});

  final CarDetail car;

  @override
  State<_VehicleActions> createState() => _VehicleActionsState();
}

class _VehicleActionsState extends State<_VehicleActions> {
  bool _sendingInterest = false;

  CarPreview get _preview {
    final CarDetail car = widget.car;
    return CarPreview(
      id: car.id,
      title: car.title,
      model: car.model,
      source: car.source,
      make: car.make,
      variant: car.variant,
      year: car.year,
      price: car.price,
      priceLabel: car.priceLabel,
      currency: car.currency,
      mileageKm: car.mileageKm,
      fuelType:
          car.fuelType ??
          (car.fuelTypes.isEmpty ? null : car.fuelTypes.join(' / ')),
      transmission: car.transmission,
      bodyType: car.bodyType,
      city: car.city,
      owner: car.owner,
      imageUrl: car.images.isEmpty ? null : car.images.first.url,
      detailAvailable: true,
    );
  }

  Future<void> _sendInterest() async {
    final AccountController account = context.read<AccountController>();
    if (!account.isAuthenticated) {
      context.push(AppRoutes.profile);
      return;
    }
    bool consent = false;
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setDialogState) =>
            AlertDialog(
              title: const Text('Send your interest?'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Carvexa will share your name, email and saved phone number with the team handling this vehicle inquiry.',
                  ),
                  const SizedBox(height: AppSpacing.md),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    value: consent,
                    onChanged: (bool? value) =>
                        setDialogState(() => consent = value ?? false),
                    title: const Text(
                      'I agree to be contacted about this vehicle.',
                    ),
                    controlAffinity: ListTileControlAffinity.leading,
                  ),
                ],
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: consent
                      ? () => Navigator.pop(dialogContext, true)
                      : null,
                  child: const Text('Send interest'),
                ),
              ],
            ),
      ),
    );
    if (accepted != true || !mounted) return;

    setState(() => _sendingInterest = true);
    try {
      final Map<String, dynamic> response = await context
          .read<ApiClient>()
          .postJson(
            '/leads',
            body: <String, dynamic>{
              'externalCarId': widget.car.id,
              'contactConsent': true,
            },
          );
      if (mounted) {
        final Object? rawNotification = response['emailNotification'];
        final String? notificationStatus =
            rawNotification is Map<String, dynamic>
            ? rawNotification['status'] as String?
            : null;
        final String message = switch (notificationStatus) {
          'accepted' =>
            'Your interest is saved. The Carvexa team has been notified.',
          'failed' || 'not_configured' =>
            'Your interest is saved, but Carvexa could not notify the team.',
          _ => 'Your interest has been saved.',
        };
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      if (mounted) {
        final String message = error.toString();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              message.contains('already expressed')
                  ? 'You have already expressed interest in this vehicle.'
                  : 'We could not send your interest. Try again.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sendingInterest = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final CarPreview preview = _preview;
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: <Widget>[
        FavoriteAction(car: preview),
        Consumer<CompareController>(
          builder: (BuildContext context, CompareController compare, _) {
            final bool selected = compare.contains(widget.car.id);
            return OutlinedButton.icon(
              onPressed: () {
                final bool changed = compare.toggle(preview);
                if (!changed) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Compare up to three vehicles at a time.'),
                    ),
                  );
                }
              },
              icon: Icon(
                selected ? Icons.check_rounded : Icons.compare_arrows_rounded,
              ),
              label: Text(selected ? 'Remove compare' : 'Compare'),
            );
          },
        ),
        OutlinedButton.icon(
          onPressed: () => context.push(AppRoutes.ai, extra: widget.car.id),
          icon: const Icon(Icons.auto_awesome_rounded),
          label: const Text('Ask AI'),
        ),
        FilledButton.icon(
          onPressed: _sendingInterest ? null : _sendInterest,
          icon: _sendingInterest
              ? const SizedBox.square(
                  dimension: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.mail_outline_rounded),
          label: const Text('I’m interested'),
        ),
      ],
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Back',
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 40,
            child: Icon(
              Icons.arrow_back_rounded,
              size: 20,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.car});

  final CarDetail car;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          car.sourceLabel.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.brand.accent,
            letterSpacing: 1.4,
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          car.title,
          style: context.text.headlineMedium,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
        if (car.variant != null) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(car.variant!, style: context.text.bodyMedium),
        ],
      ],
    );
  }
}

/// The price block, plus the catalogue's own note when no figure is published.
class _PriceBlock extends StatelessWidget {
  const _PriceBlock({required this.car, this.selectedVariant});

  final CarDetail car;
  final CarVariant? selectedVariant;

  @override
  Widget build(BuildContext context) {
    final HyderabadPriceEstimate? estimate = selectedVariant == null
        ? car.onRoadEstimate
        : HyderabadPriceEstimate.forNewCar(
            price: selectedVariant!.price,
            priceLabel: selectedVariant!.priceLabel,
            fuelType:
                selectedVariant!.fuelType ??
                (car.fuelTypes.length == 1 ? car.fuelTypes.single : null),
          );
    final bool priceAvailable = selectedVariant == null
        ? car.priceAvailable
        : estimate != null;
    final String formattedPrice = selectedVariant == null
        ? car.formattedPrice
        : estimate?.label ?? 'On-road estimate unavailable';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: <Color>[context.brand.surfaceRaised, context.brand.surface],
        ),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.lg)),
        border: Border.all(
          color: priceAvailable
              ? context.brand.accent.withValues(alpha: 0.4)
              : context.brand.outline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            (selectedVariant == null
                    ? car.priceHeading
                    : 'Selected variant on-road price')
                .toUpperCase(),
            style: context.text.labelSmall,
          ),
          const SizedBox(height: AppSpacing.xxs),
          estimate != null
              ? OnRoadPriceTooltip(
                  estimate: estimate,
                  child: Text(
                    formattedPrice,
                    style: context.text.headlineSmall?.copyWith(
                      color: context.brand.accentBright,
                    ),
                  ),
                )
              : selectedVariant == null &&
                    car.source == 'used' &&
                    car.priceAvailable
              ? UsedCarPriceTooltip(
                  askingPrice: car.formattedPrice,
                  child: Text(
                    car.formattedPrice,
                    style: context.text.headlineSmall?.copyWith(
                      color: context.brand.accentBright,
                    ),
                  ),
                )
              : Text(
                  formattedPrice,
                  style: context.text.headlineSmall?.copyWith(
                    color: priceAvailable
                        ? context.brand.accentBright
                        : context.brand.textSecondary,
                  ),
                ),
          if (!priceAvailable) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'The catalogue has not published a figure for this vehicle.',
              style: context.text.bodySmall,
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          OutlinedButton.icon(
            onPressed: () => VehicleEmiCalculator.show(
              context,
              vehicleName: selectedVariant == null
                  ? car.title
                  : '${car.title} ${selectedVariant!.name}',
              initialPrice: selectedVariant == null
                  ? car.financeAmount
                  : estimate?.minimum,
              priceDescription: car.source == 'new'
                  ? 'Estimated Hyderabad on-road amount from the published ex-showroom price'
                  : 'Hyderabad seller asking price',
            ),
            icon: const Icon(Icons.calculate_outlined),
            label: const Text('Calculate EMI'),
          ),
          if (car.source == 'new') ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Estimate assumes a first private vehicle and includes Telangana life tax, road-safety cess, registration and an approximate insurance allowance. Second-car/company rates and dealer quotes can differ.',
              style: context.text.labelSmall?.copyWith(
                color: context.brand.textTertiary,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Key facts as spec plates — the automotive "data plate" treatment rather than
/// a form.
class _KeyFacts extends StatelessWidget {
  const _KeyFacts({required this.facts});

  final List<CarSpecRow> facts;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: AppSpacing.sm,
      children: <Widget>[
        for (final CarSpecRow fact in facts)
          Container(
            constraints: const BoxConstraints(minWidth: 104),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: BoxDecoration(
              color: context.brand.surface,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(color: context.brand.outline),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  fact.label.toUpperCase(),
                  style: context.text.labelSmall?.copyWith(
                    fontSize: 8.5,
                    color: context.brand.textTertiary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  fact.value,
                  style: context.text.titleSmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// A titled table of published specification rows.
class _SpecSection extends StatelessWidget {
  const _SpecSection({required this.title, required this.items});

  final String title;
  final List<CarSpecRow> items;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return DriveInReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(title, style: context.text.headlineSmall),
          const SizedBox(height: AppSpacing.sm),
          DecoratedBox(
            decoration: BoxDecoration(
              color: context.brand.surface,
              borderRadius: const BorderRadius.all(
                Radius.circular(AppRadius.md),
              ),
              border: Border.all(color: context.brand.outline),
            ),
            child: Column(
              children: <Widget>[
                for (int i = 0; i < items.length; i++) ...<Widget>[
                  if (i > 0) Divider(height: 1, color: context.brand.outline),
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Expanded(
                          flex: 4,
                          child: Text(
                            items[i].label,
                            style: context.text.bodySmall,
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          flex: 5,
                          child: Text(
                            items[i].value,
                            textAlign: TextAlign.right,
                            style: context.text.titleSmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Published trims, each with its own real price label.
///
/// Capped by the backend; when more exist than were sent, the header says so
/// rather than implying the list is complete.
class _Variants extends StatelessWidget {
  const _Variants({
    required this.car,
    required this.selectedVariant,
    required this.variantsToCompare,
    required this.onSelected,
    required this.onCompareToggle,
    required this.onClearComparison,
  });

  final CarDetail car;
  final CarVariant? selectedVariant;
  final List<CarVariant> variantsToCompare;
  final ValueChanged<CarVariant> onSelected;
  final ValueChanged<CarVariant> onCompareToggle;
  final VoidCallback onClearComparison;

  @override
  Widget build(BuildContext context) {
    final bool truncated = car.variantCount > car.variants.length;

    return DriveInReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text('Variants', style: context.text.headlineSmall),
              ),
              if (truncated)
                Text(
                  'Showing ${car.variants.length} of ${car.variantCount}',
                  style: context.text.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          for (final CarVariant variant in car.variants)
            _VariantTile(
              variant: variant,
              selected: identical(selectedVariant, variant),
              comparing: variantsToCompare.any(
                (CarVariant item) => identical(item, variant),
              ),
              onTap: () => onSelected(variant),
              onCompareTap: () => onCompareToggle(variant),
            ),
          if (car.variants.length > 1) ...<Widget>[
            const SizedBox(height: AppSpacing.xs),
            _VariantComparison(
              variants: variantsToCompare,
              onClear: onClearComparison,
            ),
          ],
        ],
      ),
    );
  }
}

class _VariantTile extends StatelessWidget {
  const _VariantTile({
    required this.variant,
    required this.selected,
    required this.comparing,
    required this.onTap,
    required this.onCompareTap,
  });

  final CarVariant variant;
  final bool selected;
  final bool comparing;
  final VoidCallback onTap;
  final VoidCallback onCompareTap;

  @override
  Widget build(BuildContext context) {
    final Color border = selected
        ? context.brand.accentBright
        : context.brand.outline;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: context.brand.surface,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
        child: InkWell(
          onTap: onTap,
          borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
          child: Semantics(
            button: true,
            selected: selected,
            label: variant.name,
            hint: selected ? 'Selected variant' : 'Select this variant',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
                border: Border.all(color: border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          variant.name,
                          style: context.text.titleMedium,
                        ),
                      ),
                      if (selected)
                        Icon(
                          Icons.check_circle_rounded,
                          color: context.brand.accentBright,
                          size: 20,
                        ),
                      IconButton(
                        tooltip: comparing
                            ? 'Remove from variant comparison'
                            : 'Compare this variant',
                        visualDensity: VisualDensity.compact,
                        onPressed: onCompareTap,
                        icon: Icon(
                          comparing
                              ? Icons.check_box_rounded
                              : Icons.add_box_outlined,
                          color: comparing
                              ? context.brand.accentBright
                              : context.brand.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  if (variant.summary != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(variant.summary!, style: context.text.bodySmall),
                  ],
                  if (variant.priceLabel != null ||
                      variant.price != null) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Est. Hyderabad on-road: ${variant.estimatedHyderabadPrice}',
                      style: context.text.titleSmall?.copyWith(
                        color: context.brand.accentBright,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _VariantComparison extends StatelessWidget {
  const _VariantComparison({required this.variants, required this.onClear});

  final List<CarVariant> variants;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final bool ready = variants.length == 2;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.brand.surfaceRaised,
        border: Border.all(color: context.brand.outline),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  ready ? 'Variant comparison' : 'Compare variants',
                  style: context.text.titleSmall,
                ),
              ),
              if (variants.isNotEmpty)
                TextButton(onPressed: onClear, child: const Text('Clear')),
            ],
          ),
          if (!ready)
            Text(
              'Choose 2 variants using the compare icon above.',
              style: context.text.bodySmall,
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _comparisonRow(
                    context,
                    'Variant',
                    variants.map((CarVariant item) => item.name).toList(),
                    emphasized: true,
                  ),
                  _comparisonRow(
                    context,
                    'Ex-showroom',
                    variants
                        .map(
                          (CarVariant item) => item.priceLabel ?? 'Not listed',
                        )
                        .toList(),
                  ),
                  _comparisonRow(
                    context,
                    'Hyderabad on-road estimate',
                    variants
                        .map((CarVariant item) => item.estimatedHyderabadPrice)
                        .toList(),
                    emphasized: true,
                  ),
                  _comparisonRow(
                    context,
                    'Fuel',
                    variants
                        .map((CarVariant item) => item.fuelType ?? 'Not listed')
                        .toList(),
                  ),
                  _comparisonRow(
                    context,
                    'Details',
                    variants
                        .map((CarVariant item) => item.summary ?? 'Not listed')
                        .toList(),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _comparisonRow(
    BuildContext context,
    String label,
    List<String> values, {
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: emphasized
                  ? context.text.titleSmall
                  : context.text.bodySmall,
            ),
          ),
          for (final String value in values)
            SizedBox(
              width: 170,
              child: Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: Text(value, style: context.text.bodySmall),
              ),
            ),
        ],
      ),
    );
  }
}

class _VariantsUnavailable extends StatelessWidget {
  const _VariantsUnavailable();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Variant prices are not available from the catalogue for this model right now.',
      style: context.text.bodySmall?.copyWith(
        color: context.brand.textSecondary,
      ),
    );
  }
}

class _SampleDataNotice extends StatelessWidget {
  const _SampleDataNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: context.brand.surfaceRaised,
        border: Border.all(color: context.brand.outline),
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.md)),
      ),
      child: Text(
        'Sample catalogue data is shown. Photos are representative model images and may not depict a specific used car.',
        style: context.text.bodySmall?.copyWith(
          color: context.brand.textSecondary,
        ),
      ),
    );
  }
}

/// Published features as chips, with an honest "+N more" when the backend
/// capped the list.
class _Features extends StatelessWidget {
  const _Features({required this.car});

  final CarDetail car;

  @override
  Widget build(BuildContext context) {
    final int hidden = car.featureCount - car.features.length;

    return DriveInReveal(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text('Key features', style: context.text.headlineSmall),
              ),
              if (car.featureCount > 0)
                Text(
                  '${car.featureCount} listed',
                  style: context.text.bodySmall,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final String feature in car.features)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: context.brand.surfaceRaised,
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.pill),
                    ),
                  ),
                  child: Text(feature, style: context.text.bodySmall),
                ),
              if (hidden > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: const BorderRadius.all(
                      Radius.circular(AppRadius.pill),
                    ),
                    border: Border.all(color: context.brand.outline),
                  ),
                  child: Text('+$hidden more', style: context.text.bodySmall),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Loading state shaped like the real page, so nothing jumps when the vehicle
/// arrives.
class _DetailsSkeleton extends StatelessWidget {
  const _DetailsSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      children: const <Widget>[
        AspectRatio(
          aspectRatio: 16 / 9,
          child: LoadingSkeleton(
            width: double.infinity,
            height: double.infinity,
            borderRadius: 0,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(AppSpacing.pageGutter),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              LoadingSkeleton(width: 90, height: 11),
              SizedBox(height: AppSpacing.sm),
              LoadingSkeleton(width: 240, height: 22),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(
                width: double.infinity,
                height: 76,
                borderRadius: AppRadius.lg,
              ),
              SizedBox(height: AppSpacing.xl),
              LoadingSkeleton(
                width: double.infinity,
                height: 120,
                borderRadius: AppRadius.md,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
