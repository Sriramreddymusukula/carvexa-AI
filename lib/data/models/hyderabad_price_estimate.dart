import 'dart:math' as math;

/// A clearly labelled Hyderabad estimate derived from a published
/// ex-showroom figure. Insurance is an allowance, so this is never presented
/// as a dealer quotation.
class HyderabadPriceEstimate {
  const HyderabadPriceEstimate({
    required this.minimumBreakdown,
    required this.maximumBreakdown,
  });

  final HyderabadPriceBreakdown minimumBreakdown;
  final HyderabadPriceBreakdown maximumBreakdown;

  int get minimum => minimumBreakdown.total;
  int get maximum => maximumBreakdown.total;

  String get label => minimum == maximum
      ? _format(minimum)
      : '${_format(minimum)} – ${_format(maximum)}';

  static HyderabadPriceEstimate? forNewCar({
    required int? price,
    required String? priceLabel,
    String? fuelType,
  }) {
    final List<int>? range = _parsePrice(priceLabel);
    final int? low = range?.first ?? price;
    final int? high = range?.last ?? price;
    if (low == null || high == null || low <= 0 || high < low) return null;
    return HyderabadPriceEstimate(
      minimumBreakdown: _breakdown(low, fuelType),
      maximumBreakdown: _breakdown(high, fuelType),
    );
  }

  /// A multiline breakdown used by the hover/long-press price tooltip.
  String get breakdownMessage {
    final bool isRange = minimum != maximum;
    final String lifeTaxRate =
        minimumBreakdown.lifeTaxRate == maximumBreakdown.lifeTaxRate
        ? '${(minimumBreakdown.lifeTaxRate * 100).round()}%'
        : '${(minimumBreakdown.lifeTaxRate * 100).round()}–${(maximumBreakdown.lifeTaxRate * 100).round()}%';
    String line(String title, int low, int high) {
      final String amount = isRange
          ? '${_format(low)} – ${_format(high)}'
          : _format(low);
      return '$title: $amount';
    }

    return <String>[
      'Hyderabad on-road estimate',
      line(
        'Ex-showroom (GST included)',
        minimumBreakdown.exShowroom,
        maximumBreakdown.exShowroom,
      ),
      line(
        'Telangana lifetime road tax / RTO ($lifeTaxRate)',
        minimumBreakdown.lifeTax,
        maximumBreakdown.lifeTax,
      ),
      line(
        'Insurance allowance (~3%)',
        minimumBreakdown.insurance,
        maximumBreakdown.insurance,
      ),
      line(
        'Road-safety cess',
        minimumBreakdown.roadSafetyCess,
        maximumBreakdown.roadSafetyCess,
      ),
      line(
        'RTO registration fee',
        minimumBreakdown.registrationFee,
        maximumBreakdown.registrationFee,
      ),
      line(
        'Smart-card fee',
        minimumBreakdown.smartCardFee,
        maximumBreakdown.smartCardFee,
      ),
      line('Estimated on-road total', minimum, maximum),
      '',
      'Insurance is an allowance, not a quote. Actual premium depends on insurer, IDV and cover. Dealer options may cost extra; eligible EV benefits can change RTO charges.',
    ].join('\n');
  }

  static HyderabadPriceBreakdown _breakdown(int exShowroom, String? fuelType) {
    final String fuel = (fuelType ?? '').toLowerCase();
    final bool pureElectric =
        fuel.contains('electric') &&
        !fuel.contains('petrol') &&
        !fuel.contains('diesel') &&
        !fuel.contains('hybrid');
    final bool electricExemptionActive = DateTime.now().isBefore(
      DateTime(2027),
    );
    final bool exemptElectric = pureElectric && electricExemptionActive;
    final double taxRate = switch (exShowroom) {
      < 500000 => .13,
      < 1000000 => .14,
      < 2000000 => .18,
      < 5000000 => .20,
      _ => .21,
    };
    // Estimate includes Telangana life tax, ₹5,000 road-safety cess,
    // registration + smart-card fees, and a 3% insurance allowance.
    // Telangana GO Ms. 41 exempts eligible EVs from life tax and registration
    // through 2026; the separate road-safety cess still applies.
    final int registrationFee = exemptElectric ? 0 : 600;
    final int smartCardFee = exemptElectric ? 0 : 200;
    final int lifeTax = exemptElectric ? 0 : (exShowroom * taxRate).round();
    final int insurance = (exShowroom * .03).round();
    const int roadSafetyCess = 5000;
    return HyderabadPriceBreakdown(
      exShowroom: exShowroom,
      lifeTax: lifeTax,
      lifeTaxRate: exemptElectric ? 0 : taxRate,
      insurance: insurance,
      roadSafetyCess: roadSafetyCess,
      registrationFee: registrationFee,
      smartCardFee: smartCardFee,
      total:
          exShowroom +
          lifeTax +
          insurance +
          roadSafetyCess +
          registrationFee +
          smartCardFee,
    );
  }

  static List<int>? _parsePrice(String? label) {
    if (label == null) return null;
    final RegExpMatch? match = RegExp(
      r'([\d,.]+)\s*(crore|cr|lakh|lac|l)?\s*(?:[-–]\s*₹?\s*([\d,.]+)\s*(crore|cr|lakh|lac|l)?)?',
      caseSensitive: false,
    ).firstMatch(label.replaceAll(',', ''));
    if (match == null) return null;
    final String? firstText = match.group(1);
    if (firstText == null) return null;
    final String? firstUnit = match.group(2) ?? match.group(4);
    final String? secondText = match.group(3);
    final String? secondUnit = match.group(4) ?? match.group(2);
    final int? first = _amount(firstText, firstUnit);
    final int? second = secondText == null
        ? first
        : _amount(secondText, secondUnit);
    if (first == null || second == null) return null;
    return <int>[math.min(first, second), math.max(first, second)];
  }

  static int? _amount(String value, String? unit) {
    final double? number = double.tryParse(value);
    if (number == null) return null;
    final String normalized = (unit ?? '').toLowerCase();
    final double multiplier = switch (normalized) {
      'crore' || 'cr' => 10000000,
      'lakh' || 'lac' || 'l' => 100000,
      _ => 1,
    };
    return (number * multiplier).round();
  }

  static String _format(int amount) {
    if (amount >= 10000000) {
      return '₹${(amount / 10000000).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} Cr';
    }
    if (amount >= 100000) {
      return '₹${(amount / 100000).toStringAsFixed(2).replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '')} Lakh';
    }
    final String digits = amount.toString();
    if (digits.length <= 3) return '₹$digits';
    final String lastThree = digits.substring(digits.length - 3);
    final String rest = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(RegExp(r'\B(?=(\d{2})+(?!\d))'), (_) => ',');
    return '₹$rest,$lastThree';
  }
}

class HyderabadPriceBreakdown {
  const HyderabadPriceBreakdown({
    required this.exShowroom,
    required this.lifeTax,
    required this.lifeTaxRate,
    required this.insurance,
    required this.roadSafetyCess,
    required this.registrationFee,
    required this.smartCardFee,
    required this.total,
  });

  final int exShowroom;
  final int lifeTax;
  final double lifeTaxRate;
  final int insurance;
  final int roadSafetyCess;
  final int registrationFee;
  final int smartCardFee;
  final int total;
}
