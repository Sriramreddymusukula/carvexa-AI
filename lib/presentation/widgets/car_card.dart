import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_motion.dart';
import '../../core/theme/app_spacing.dart';
import '../../core/utils/responsive.dart';
import '../../data/models/car_preview.dart';
import 'on_road_price_tooltip.dart';
import '../motion/pressable_scale.dart';
import 'automotive_image.dart';
import 'vehicle_emi_calculator.dart';
import 'vehicle_silhouette.dart';

/// Layout variant.
enum CarCardLayout {
  /// Horizontal: image left, details right. Used in rails and lists.
  horizontal,

  /// Stacked: image on top, details below. Used in grids.
  stacked,
}

/// The vehicle card.
///
/// Deliberately one component with two layouts rather than two components: the
/// image treatment, price formatting, spec pills and press feedback must be
/// identical, and only the arrangement should differ.
class CarCard extends StatefulWidget {
  const CarCard({
    super.key,
    required this.car,
    this.layout = CarCardLayout.horizontal,
    this.onTap,
    this.trailing,
    this.favoriteAction,
    this.showSpecs = true,
    this.onCompare,
    this.comparing = false,
  });

  final CarPreview car;
  final CarCardLayout layout;
  final VoidCallback? onTap;

  /// Optional trailing control, such as the account favorite action.
  final Widget? trailing;
  final Widget? favoriteAction;

  /// Spec pills are hidden on the stacked layout to keep tiles compact.
  final bool showSpecs;

  /// Adds/removes this vehicle from the comparison shortlist.
  ///
  /// Null hides the control entirely, so a card that must not be compared
  /// simply does not offer it rather than offering a broken action.
  final VoidCallback? onCompare;

  /// Whether this vehicle is currently on the shortlist.
  final bool comparing;

  @override
  State<CarCard> createState() => _CarCardState();
}

class _CarCardState extends State<CarCard> {
  bool _hovered = false;

  bool get _hoverEnabled => Responsive.supportsHover(context);

  @override
  Widget build(BuildContext context) {
    final Widget body = switch (widget.layout) {
      CarCardLayout.horizontal => _buildHorizontal(context),
      CarCardLayout.stacked => _buildStacked(context),
    };

    return PressableScale(
      onTap: widget.onTap,
      hoverElevation: AppElevation.card,
      semanticLabel: '${widget.car.displayName}, ${widget.car.formattedPrice}',
      semanticHint: 'Opens the vehicle details',
      child: AnimatedContainer(
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        decoration: BoxDecoration(
          color: context.brand.surface,
          borderRadius: AppRadius.cardRadius,
          border: Border.all(
            color: _hovered
                ? context.brand.accent.withValues(alpha: 0.45)
                : context.brand.outline,
          ),
          boxShadow: _hovered ? AppElevation.card : AppElevation.none,
        ),
        child: Stack(
          children: <Widget>[
            body,
            if (widget.favoriteAction != null)
              Positioned(
                top: AppSpacing.xs,
                left: AppSpacing.xs,
                child: widget.favoriteAction!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _image(
    BuildContext context, {
    required double aspectRatio,
    bool fillHeight = false,
  }) {
    final Widget image = AutomotiveImage(
      imageUrl: widget.car.imageUrl,
      aspectRatio: aspectRatio,
      fillHeight: fillHeight,
      silhouetteColor: context.brand.textTertiary.withValues(alpha: 0.45),
      semanticLabel: '${widget.car.displayName} image',
    );

    if (!_hoverEnabled) return image;

    // Zoom only where a pointer exists; a touch device never enters this.
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? AppMotion.hoverZoom : 1.0,
        duration: AppMotion.medium,
        curve: AppMotion.standard,
        // Keep the image under its parent's finite constraints. An
        // unconstrained OverflowBox makes StackFit.expand descendants ask
        // for infinite dimensions on Flutter Web.
        child: image,
      ),
    );
  }

  Widget _buildHorizontal(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: 112,
          child: _image(context, aspectRatio: AutomotiveImageRatio.card),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: _details(context, showSpecs: widget.showSpecs),
          ),
        ),
        if (widget.trailing != null)
          Padding(
            padding: const EdgeInsets.only(
              right: AppSpacing.sm,
              top: AppSpacing.sm,
            ),
            child: widget.trailing,
          ),
      ],
    );
  }

  Widget _buildStacked(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // A grid tile can be short (two columns on a 320dp phone) or tall
        // (four columns on a tablet). Below this height the secondary line
        // is dropped rather than allowed to overflow.
        // 150dp is the measured height of the image (width * 3/4) plus the full
        // text block. Below it the secondary line is dropped, which is what
        // keeps a two-column tile on a 320dp phone - and a narrow landscape
        // window - from overflowing.
        return _stackedBody(context, minimal: constraints.maxHeight < 150);
      },
    );
  }

  Widget _stackedBody(BuildContext context, {required bool minimal}) {
    return Stack(
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // The text and the image are both flexible (3:2) and the text is
            // clipped. That combination makes overflow structurally impossible:
            // the flex layout always fits both children into the tile, and
            // ClipRect keeps the text inside its share on an extremely short
            // tile.
            Expanded(
              flex: 3,
              child: _image(
                context,
                aspectRatio: AutomotiveImageRatio.tile,
                fillHeight: true,
              ),
            ),
            Flexible(
              flex: 2,
              child: ClipRect(
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: FittedBox(
                    // scaleDown only engages when the tile is too short for the
                    // text, which is exactly the case a hard failure would be
                    // wrong for.
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topLeft,
                    child: _details(
                      context,
                      showSpecs: false,
                      minimal: minimal,
                    ),
                  ),
                ),
              ),
            ),
            if (widget.trailing != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: widget.trailing,
              ),
          ],
        ),
        if (widget.onCompare != null)
          Positioned(
            top: AppSpacing.xs,
            right: AppSpacing.xs,
            child: _compareBadge(context),
          ),
      ],
    );
  }

  /// The add/remove control for the comparison shortlist.
  ///
  /// Sits over the photograph rather than in the text block so it costs no
  /// vertical space in a tile that is already height-constrained.
  Widget _compareBadge(BuildContext context) {
    final bool selected = widget.comparing;

    return Semantics(
      button: true,
      selected: selected,
      label: selected ? 'Remove from comparison' : 'Add to comparison',
      child: Material(
        color: selected
            ? context.brand.accent
            : Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        child: InkWell(
          onTap: widget.onCompare,
          customBorder: const CircleBorder(),
          child: SizedBox.square(
            dimension: 30,
            child: Icon(
              selected ? Icons.check_rounded : Icons.compare_arrows_rounded,
              size: 16,
              color: selected ? const Color(0xFF1A1005) : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _details(
    BuildContext context, {
    required bool showSpecs,
    bool compact = false,
    bool minimal = false,
  }) {
    final CarPreview car = widget.car;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          car.sourceLabel.toUpperCase(),
          style: context.text.labelSmall?.copyWith(
            color: context.brand.accent,
            fontSize: 9.5,
          ),
        ),
        const SizedBox(height: AppSpacing.xxs),
        Text(
          car.shortName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.titleMedium,
        ),
        // The year/body line is the first thing to go when a tile is short,
        // so the name and price - the two things that matter - always survive.
        if (!minimal) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            _secondaryLine(car),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall,
          ),
        ],
        // A used listing is sold by a person from a place, and that is the first
        // thing a buyer looks for. New models have no seller, so the line is
        // simply absent for them rather than filled with a placeholder.
        if (!minimal && car.sellerLabel != null) ...<Widget>[
          const SizedBox(height: 1),
          Text(
            car.sellerLabel!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelSmall?.copyWith(
              fontSize: 9.5,
              color: context.brand.textTertiary,
            ),
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          car.priceHeading,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelSmall?.copyWith(
            color: context.brand.textTertiary,
          ),
        ),
        _priceLabel(
          context,
          car,
          context.text.titleMedium?.copyWith(color: context.brand.accentBright),
        ),
        if (!minimal) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => VehicleEmiCalculator.show(
                context,
                vehicleName: car.displayName,
                initialPrice: car.financeAmount,
                priceDescription: car.source == 'new'
                    ? 'Estimated Hyderabad on-road amount from published ex-showroom price'
                    : 'Hyderabad seller asking price',
              ),
              icon: const Icon(Icons.calculate_outlined, size: 16),
              label: const Text('EMI calculator'),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: const Size(0, 34),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
        if (showSpecs && !compact) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: <Widget>[
              if (car.fuelType != null) _MiniSpec(label: car.fuelType!),
              if (car.transmission != null) _MiniSpec(label: car.transmission!),
              if (car.city != null) _MiniSpec(label: car.city!),
            ],
          ),
        ],
      ],
    );
  }

  /// The line under the vehicle name, built only from published facts.
  ///
  /// A real listing often has a year and a mileage but no body type, so the
  /// parts are joined from whatever exists. When the catalogue published
  /// nothing at all, the source label stands in rather than a blank line.
  String _secondaryLine(CarPreview car) {
    final List<String> parts = <String>[
      if (car.year != null) '${car.year}',
      if (car.bodyType != null) car.bodyType!,
      if (car.mileageLabel != null) car.mileageLabel!,
    ];
    return parts.isEmpty ? car.sourceLabel : parts.join('  ·  ');
  }
}

/// Small spec pill used inside a card.
class _MiniSpec extends StatelessWidget {
  const _MiniSpec({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 3,
      ),
      decoration: BoxDecoration(
        color: context.brand.surfaceRaised,
        borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.labelSmall?.copyWith(
          fontSize: 9.5,
          letterSpacing: 0.5,
          color: context.brand.textSecondary,
        ),
      ),
    );
  }
}

/// Full-bleed hero card for the featured vehicle.
class CarShowcaseCard extends StatelessWidget {
  const CarShowcaseCard({super.key, required this.car, this.onTap});

  final CarPreview car;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: 'Featured vehicle, ${car.displayName}',
      semanticHint: 'Opens the vehicle details',
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[context.brand.surfaceRaised, context.brand.surface],
          ),
          border: Border.all(color: context.brand.outline),
          boxShadow: AppElevation.raised,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Stack(
              children: <Widget>[
                AutomotiveImage(
                  imageUrl: car.imageUrl,
                  aspectRatio: AutomotiveImageRatio.hero,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(AppRadius.lg),
                  ),
                  silhouetteColor: context.brand.accent.withValues(alpha: 0.5),
                  semanticLabel: '${car.displayName} image',
                  overlay: DecoratedBox(
                    // Scrim keeps overlaid text legible on any photo.
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: <Color>[
                          Colors.transparent,
                          context.brand.surface.withValues(alpha: 0.85),
                        ],
                        stops: const <double>[0.55, 1.0],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: AppSpacing.lg,
                  bottom: AppSpacing.lg,
                  right: AppSpacing.lg,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'FEATURED',
                        style: context.text.labelSmall?.copyWith(
                          color: context.brand.accent,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        car.displayName,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.headlineMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          car.priceHeading,
                          style: context.text.labelSmall?.copyWith(
                            color: context.brand.textTertiary,
                          ),
                        ),
                        const SizedBox(height: AppSpacing.xxs),
                        _priceLabel(
                          context,
                          car,
                          context.text.titleLarge?.copyWith(
                            color: context.brand.accentBright,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: context.brand.accent,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget _priceLabel(BuildContext context, CarPreview car, TextStyle? style) {
  final Widget price = Text(
    car.formattedPrice,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: style,
  );
  final estimate = car.onRoadEstimate;
  if (estimate != null) {
    return OnRoadPriceTooltip(estimate: estimate, child: price);
  }
  return car.source == 'used'
      ? UsedCarPriceTooltip(askingPrice: car.formattedPrice, child: price)
      : price;
}
