import 'package:flutter/foundation.dart';

import 'hyderabad_price_estimate.dart';

/// A vehicle as it is presented in a card or list.
///
/// This is deliberately a **presentation model**, not a wire model. It is built
/// by `CarCatalogDto` from our own backend's normalised shape, so the UI never
/// sees a provider field name and swapping providers changes no screen.
///
/// Every field that a real catalogue may simply not publish is nullable here,
/// and the UI reads it through a getter that says "not available" rather than
/// rendering a blank. Nothing in this model invents a value.
@immutable
class CarPreview {
  const CarPreview({
    required this.id,
    required this.title,
    required this.model,
    required this.source,
    this.make,
    this.variant,
    this.year,
    this.price,
    this.priceLabel,
    this.currency = 'INR',
    this.mileageKm,
    this.fuelType,
    this.transmission,
    this.bodyType,
    this.city,
    this.owner,
    this.imageUrl,
    this.detailAvailable = false,
  });

  /// Opaque identifier minted by our backend. Never a provider URL.
  final String id;

  /// Display name, e.g. "Volvo XC90 B5 AWD" or "Tata Nexon".
  final String title;

  /// Model without the brand, when the source separates them.
  final String model;

  /// Which catalogue this came from: `used` or `new`. Drives the card's label
  /// and which detail page opens.
  final String source;

  /// Brand, when the source publishes it. Null for used listings, which the
  /// source only reports as one combined string.
  final String? make;

  final String? variant;
  final int? year;

  /// Numeric price in [currency]; null when the source has not published one.
  final int? price;

  /// The source's own formatted price or price range, when published.
  final String? priceLabel;

  final String currency;

  final int? mileageKm;
  final String? fuelType;
  final String? transmission;
  final String? bodyType;
  final String? city;
  final String? owner;

  /// Real photograph, or null so `AutomotiveImage` draws its designed
  /// placeholder rather than a broken image.
  final String? imageUrl;

  /// Whether a details page exists for this item. False means the card is
  /// informational and must not navigate.
  final bool detailAvailable;

  /// Which catalogue a card came from, so the UI can label it honestly.
  String get sourceLabel => switch (source) {
    'new' => 'New car',
    'used' => 'Used car',
    _ => 'Car',
  };

  /// True only for a used listing, which is the only kind of vehicle that has a
  /// seller. New models are sold by the manufacturer, so showing a seller for
  /// one would be inventing a fact.
  bool get isUsed => source == 'used';

  /// Who is selling the vehicle and where they are, e.g. "First owner · Gurgaon".
  ///
  /// A used listing without this says nothing about the seller, and the UI must
  /// show nothing rather than a placeholder: "owner unknown" is a claim the
  /// catalogue never made.
  String? get sellerLabel {
    if (!isUsed) return null;
    final List<String> parts = <String>[?owner, ?city];
    return parts.isEmpty ? null : parts.join('  ·  ');
  }

  String get displayName => title;

  /// Short form for dense layouts: "XC90 B5 AWD".
  String get shortName => variant == null ? model : '$model $variant';

  /// True when a price was actually published. The UI uses this to choose
  /// between showing a figure and saying "price on request".
  HyderabadPriceEstimate? get onRoadEstimate => source == 'new'
      ? HyderabadPriceEstimate.forNewCar(
          price: price,
          priceLabel: priceLabel,
          fuelType: fuelType,
        )
      : null;

  bool get priceAvailable => source == 'new'
      ? onRoadEstimate != null
      : priceLabel != null || price != null;

  /// Never blank: a new car without a published price cannot be estimated, and
  /// a used listing without a published asking price says so plainly.
  String get formattedPrice => source == 'new'
      ? onRoadEstimate?.label ?? 'On-road estimate unavailable'
      : priceLabel ?? 'Price on request';

  String get priceHeading =>
      source == 'new' ? 'Est. Hyderabad on-road' : 'Hyderabad asking price';

  int? get financeAmount => source == 'new' ? onRoadEstimate?.minimum : price;

  /// "21,500 km" or null when the source does not publish mileage.
  String? get mileageLabel =>
      mileageKm == null ? null : '${_grouped(mileageKm!)} km';

  String? get locationLabel => city;

  List<CarSpec> get specs => <CarSpec>[
    if (mileageKm != null) CarSpec('Mileage', mileageLabel!),
    if (fuelType != null) CarSpec('Fuel', fuelType!),
    if (transmission != null) CarSpec('Gearbox', transmission!),
    if (bodyType != null) CarSpec('Body', bodyType!),
    if (year != null) CarSpec('Year', '$year'),
  ];

  static String _grouped(int value) {
    final String digits = value.toString();
    final String lastThree = digits.length <= 3
        ? digits
        : digits.substring(digits.length - 3);
    if (digits.length <= 3) return digits;
    final String rest = digits
        .substring(0, digits.length - 3)
        .replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+$)'),
          (Match match) => '${match[1]},',
        );
    return '$rest,$lastThree';
  }
}

/// A single labelled specification, used in spec plates and detail rows.
@immutable
class CarSpec {
  const CarSpec(this.label, this.value);

  final String label;
  final String value;
}
