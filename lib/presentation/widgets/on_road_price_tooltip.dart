import 'package:flutter/material.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';
import '../../data/models/hyderabad_price_estimate.dart';

/// A tap-to-expand Hyderabad on-road price breakdown.
///
/// The historical class name is retained because existing car cards and the
/// details screen use it. The interaction is an inline dropdown, so it works
/// on touch screens as well as with a mouse.
class OnRoadPriceTooltip extends StatelessWidget {
  const OnRoadPriceTooltip({
    super.key,
    required this.estimate,
    required this.child,
  });

  final HyderabadPriceEstimate estimate;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final bool isRange = estimate.minimum != estimate.maximum;
    final List<(String, int, int)> rows = <(String, int, int)>[
      (
        'Ex-showroom (GST included)',
        estimate.minimumBreakdown.exShowroom,
        estimate.maximumBreakdown.exShowroom,
      ),
      (
        'Telangana life tax / RTO (${_formatTaxRate(estimate)})',
        estimate.minimumBreakdown.lifeTax,
        estimate.maximumBreakdown.lifeTax,
      ),
      (
        'Insurance estimate',
        estimate.minimumBreakdown.insurance,
        estimate.maximumBreakdown.insurance,
      ),
      (
        'Road-safety cess',
        estimate.minimumBreakdown.roadSafetyCess,
        estimate.maximumBreakdown.roadSafetyCess,
      ),
      (
        'RTO registration',
        estimate.minimumBreakdown.registrationFee,
        estimate.maximumBreakdown.registrationFee,
      ),
      (
        'Smart-card fee',
        estimate.minimumBreakdown.smartCardFee,
        estimate.maximumBreakdown.smartCardFee,
      ),
    ];

    return _PriceBreakdownDropdown(
      child: child,
      heading: 'Hyderabad on-road estimate',
      rows: rows,
      total: ('Estimated on-road total', estimate.minimum, estimate.maximum),
      note: 'Insurance is an allowance, not a quote. Actual premium depends on insurer, IDV and cover. Dealer options may cost extra; eligible EV benefits can change RTO charges.',
      isRange: isRange,
    );
  }
}

/// Explains which costs are still unknown when a used listing only gives an
/// asking price. It deliberately avoids inventing transfer or insurance fees.
class UsedCarPriceTooltip extends StatelessWidget {
  const UsedCarPriceTooltip({
    super.key,
    required this.askingPrice,
    required this.child,
  });

  final String askingPrice;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _PriceBreakdownDropdown(
      child: child,
      heading: 'Hyderabad used-car asking price',
      rows: <(String, int, int)>[],
      isRange: false,
      usedAskingPrice: askingPrice,
      note: 'This is not a final on-road total. Insurance status or renewal, ownership-transfer fees, pending tax and loan dues depend on the exact vehicle. Confirm these with the seller and RTO before buying.',
    );
  }
}

class _PriceBreakdownDropdown extends StatefulWidget {
  const _PriceBreakdownDropdown({
    required this.child,
    required this.heading,
    required this.rows,
    required this.isRange,
    required this.note,
    this.total,
    this.usedAskingPrice,
  });

  final Widget child;
  final String heading;
  final List<(String, int, int)> rows;
  final bool isRange;
  final String note;
  final (String, int, int)? total;
  final String? usedAskingPrice;

  @override
  State<_PriceBreakdownDropdown> createState() =>
      _PriceBreakdownDropdownState();
}

class _PriceBreakdownDropdownState extends State<_PriceBreakdownDropdown> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final Color borderColor = context.brand.outline;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Semantics(
          button: true,
          expanded: _expanded,
          label: 'Price breakdown',
          hint: _expanded ? 'Hide price breakdown' : 'Show price breakdown',
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            borderRadius: const BorderRadius.all(Radius.circular(AppRadius.xs)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Flexible(child: widget.child),
                  const SizedBox(width: AppSpacing.xs),
                  Icon(
                    _expanded ? Icons.keyboard_arrow_up : Icons.expand_more,
                    size: 20,
                    color: context.brand.accent,
                  ),
                ],
              ),
            ),
          ),
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Container(
              width: double.infinity,
              margin: const EdgeInsets.only(top: AppSpacing.sm),
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.brand.surfaceRaised,
                border: Border.all(color: borderColor),
                borderRadius: const BorderRadius.all(
                  Radius.circular(AppRadius.md),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Text(widget.heading, style: context.text.titleSmall),
                  const SizedBox(height: AppSpacing.sm),
                  if (widget.usedAskingPrice != null)
                    _priceRow(
                      context,
                      'Seller/listing price',
                      widget.usedAskingPrice!,
                      emphasized: true,
                    )
                  else ...<Widget>[
                    for (final (String label, int low, int high) in widget.rows)
                      _priceRow(
                        context,
                        label,
                        _formatRange(low, high, widget.isRange),
                      ),
                    if (widget.total case final total?) ...<Widget>[
                      const Divider(height: AppSpacing.lg),
                      _priceRow(
                        context,
                        total.$1,
                        _formatRange(total.$2, total.$3, widget.isRange),
                        emphasized: true,
                      ),
                    ],
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    widget.note,
                    style: context.text.bodySmall?.copyWith(
                      color: context.brand.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            crossFadeState: _expanded
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 180),
            sizeCurve: Curves.easeInOut,
          ),
        ),
      ],
    );
  }

  Widget _priceRow(
    BuildContext context,
    String label,
    String value, {
    bool emphasized = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xxs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Text(
              label,
              style: emphasized
                  ? context.text.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    )
                  : context.text.bodySmall,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            value,
            textAlign: TextAlign.end,
            style: emphasized
                ? context.text.bodyMedium?.copyWith(
                    color: context.brand.accentBright,
                    fontWeight: FontWeight.w700,
                  )
                : context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}

String _formatRange(int low, int high, bool isRange) {
  final String first = _formatRupees(low);
  return isRange ? '$first – ${_formatRupees(high)}' : first;
}

String _formatTaxRate(HyderabadPriceEstimate estimate) {
  final int low = (estimate.minimumBreakdown.lifeTaxRate * 100).round();
  final int high = (estimate.maximumBreakdown.lifeTaxRate * 100).round();
  return low == high ? '$low%' : '$low–$high%';
}

String _formatRupees(int amount) {
  if (amount >= 10000000) {
    return '₹${_trimDecimal(amount / 10000000)} Cr';
  }
  if (amount >= 100000) return '₹${_trimDecimal(amount / 100000)} Lakh';
  final String digits = amount.toString();
  if (digits.length <= 3) return '₹$digits';
  final String lastThree = digits.substring(digits.length - 3);
  final String rest = digits
      .substring(0, digits.length - 3)
      .replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
  return '₹$rest,$lastThree';
}

String _trimDecimal(double value) => value
    .toStringAsFixed(2)
    .replaceFirst(RegExp(r'0+$'), '')
    .replaceFirst(RegExp(r'\.$'), '');
