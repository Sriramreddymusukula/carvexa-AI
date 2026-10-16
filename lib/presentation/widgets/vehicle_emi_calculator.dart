import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/extensions/context_extensions.dart';
import '../../core/theme/app_spacing.dart';

/// Opens an editable monthly-loan estimate for a car's Hyderabad price.
class VehicleEmiCalculator extends StatefulWidget {
  const VehicleEmiCalculator({
    super.key,
    required this.vehicleName,
    required this.initialPrice,
    required this.priceDescription,
  });

  final String vehicleName;
  final int? initialPrice;
  final String priceDescription;

  static Future<void> show(
    BuildContext context, {
    required String vehicleName,
    required int? initialPrice,
    required String priceDescription,
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (_) => VehicleEmiCalculator(
      vehicleName: vehicleName,
      initialPrice: initialPrice,
      priceDescription: priceDescription,
    ),
  );

  @override
  State<VehicleEmiCalculator> createState() => _VehicleEmiCalculatorState();
}

class _VehicleEmiCalculatorState extends State<VehicleEmiCalculator> {
  late final TextEditingController _price;
  late final TextEditingController _downPayment;
  late final TextEditingController _rate;
  int _months = 60;

  @override
  void initState() {
    super.initState();
    final int amount = widget.initialPrice ?? 0;
    _price = TextEditingController(text: amount == 0 ? '' : '$amount');
    _downPayment = TextEditingController(
      text: amount == 0 ? '' : '${amount ~/ 5}',
    );
    _rate = TextEditingController(text: '9');
    for (final TextEditingController controller in <TextEditingController>[
      _price,
      _downPayment,
      _rate,
    ]) {
      controller.addListener(_refresh);
    }
  }

  @override
  void dispose() {
    _price.dispose();
    _downPayment.dispose();
    _rate.dispose();
    super.dispose();
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  int get _principal =>
      math.max(0, (_parse(_price.text) - _parse(_downPayment.text)).toInt());

  double get _emi {
    final double monthlyRate = (double.tryParse(_rate.text) ?? 0) / 1200;
    if (_principal == 0) return 0;
    if (monthlyRate == 0) return _principal / _months;
    final double factor = math.pow(1 + monthlyRate, _months).toDouble();
    return _principal * monthlyRate * factor / (factor - 1);
  }

  @override
  Widget build(BuildContext context) {
    final double total = _emi * _months;
    final int principal = _principal;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.pageGutter,
        AppSpacing.lg,
        AppSpacing.pageGutter,
        MediaQuery.viewInsetsOf(context).bottom + AppSpacing.lg,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text('EMI calculator', style: context.text.headlineSmall),
            const SizedBox(height: AppSpacing.xxs),
            Text(widget.vehicleName, style: context.text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            Text(
              widget.priceDescription,
              style: context.text.bodySmall?.copyWith(
                color: context.brand.textSecondary,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            _amountField(_price, 'Vehicle price (₹)'),
            const SizedBox(height: AppSpacing.sm),
            _amountField(_downPayment, 'Down payment (₹)'),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              controller: _rate,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              decoration: const InputDecoration(
                labelText: 'Annual interest rate (%)',
                suffixIcon: Icon(Icons.percent_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Loan term: ${_months ~/ 12} years',
              style: context.text.titleSmall,
            ),
            Slider(
              value: _months.toDouble(),
              min: 12,
              max: 96,
              divisions: 7,
              label: '${_months ~/ 12} years',
              onChanged: (double value) =>
                  setState(() => _months = value.round()),
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.brand.surfaceRaised,
                borderRadius: AppRadius.cardRadius,
                border: Border.all(color: context.brand.outline),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text('Estimated monthly EMI', style: context.text.bodySmall),
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    principal > 0
                        ? _rupees(_emi.round())
                        : 'Enter a vehicle price',
                    style: context.text.headlineSmall?.copyWith(
                      color: context.brand.accentBright,
                    ),
                  ),
                  if (principal > 0) ...<Widget>[
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Loan amount  ${_rupees(principal)}',
                      style: context.text.bodySmall,
                    ),
                    Text(
                      'Total paid  ${_rupees(total.round())}',
                      style: context.text.bodySmall,
                    ),
                    Text(
                      'Interest  ${_rupees((total - principal).round())}',
                      style: context.text.bodySmall,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Illustrative estimate only. Lender rates, insurance and dealer charges vary.',
              style: context.text.labelSmall?.copyWith(
                color: context.brand.textTertiary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountField(TextEditingController controller, String label) =>
      TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: <TextInputFormatter>[
          FilteringTextInputFormatter.digitsOnly,
        ],
        decoration: InputDecoration(labelText: label),
      );

  int _parse(String value) => int.tryParse(value.replaceAll(',', '')) ?? 0;

  String _rupees(int amount) {
    final String digits = amount.toString();
    if (digits.length <= 3) return '₹$digits';
    final String lastThree = digits.substring(digits.length - 3);
    final String rest = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
    return '₹$rest,$lastThree';
  }
}
