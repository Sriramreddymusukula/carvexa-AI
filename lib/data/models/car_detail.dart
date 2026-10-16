import 'package:flutter/foundation.dart';

import 'hyderabad_price_estimate.dart';

/// One real photograph, with the context the catalogue published alongside it.
@immutable
class CarImage {
  const CarImage({required this.url, this.alt, this.category});

  final String url;

  /// Provider alt text, e.g. "Tata Nexon Front Left Side Image".
  final String? alt;

  /// Provider category, e.g. "front left side" or "interior".
  final String? category;
}

/// A labelled value the catalogue published, e.g. ("Max power", "74.46 bhp").
@immutable
class CarSpecRow {
  const CarSpecRow({required this.label, required this.value});

  final String label;
  final String value;
}

/// A titled group of specification rows, e.g. "Engine & Transmission".
@immutable
class CarSpecSection {
  const CarSpecSection({required this.title, required this.items});

  final String title;
  final List<CarSpecRow> items;
}

/// One trim of a model. Real only: [priceLabel] is the catalogue's own string.
@immutable
class CarVariant {
  const CarVariant({
    required this.name,
    this.priceLabel,
    this.price,
    this.fuelType,
    this.summary,
  });

  final String name;
  final String? priceLabel;
  final int? price;
  final String? fuelType;

  /// e.g. "1199 cc, Manual, Petrol, 17.44 kmpl".
  final String? summary;

  String get estimatedHyderabadPrice =>
      HyderabadPriceEstimate.forNewCar(
        price: price,
        priceLabel: priceLabel,
        fuelType: fuelType,
      )?.label ??
      'On-road estimate unavailable';
}

/// A vehicle's detail page.
///
/// Assembled by `CarCatalogDto` from our backend's normalised shape. Anything
/// the catalogue did not publish is null or an empty list, and the UI hides the
/// corresponding section rather than showing an empty box or a placeholder
/// number.
@immutable
class CarDetail {
  const CarDetail({
    required this.id,
    required this.source,
    required this.title,
    required this.model,
    this.make,
    this.variant,
    this.year,
    this.price,
    this.priceLabel,
    this.priceRange,
    this.currency = 'INR',
    this.bodyType,
    this.fuelType,
    this.fuelTypes = const <String>[],
    this.transmission,
    this.mileage,
    this.safetyRating,
    this.seatingCapacity,
    this.mileageKm,
    this.city,
    this.owner,
    this.images = const <CarImage>[],
    this.spinImages = const <CarImage>[],
    this.variants = const <CarVariant>[],
    this.variantCount = 0,
    this.features = const <String>[],
    this.featureCount = 0,
    this.engineSpecs = const <CarSpecRow>[],
    this.dimensions = const <CarSpecRow>[],
    this.specificationSections = const <CarSpecSection>[],
    this.overview = const <CarSpecRow>[],
    this.moreInfoUrl,
    this.catalogOrigin,
  });

  final String id;
  final String source;
  final String title;
  final String? make;
  final String model;
  final String? variant;
  final int? year;
  final int? price;
  final String? priceLabel;

  /// Ex-showroom range, when the catalogue publishes one instead of a figure.
  final String? priceRange;

  final String currency;
  final String? bodyType;
  final String? fuelType;
  final List<String> fuelTypes;
  final String? transmission;

  /// e.g. "17.44 - 20.15 kmpl", when published.
  final String? mileage;

  final String? safetyRating;
  final String? seatingCapacity;
  final int? mileageKm;
  final String? city;
  final String? owner;

  final List<CarImage> images;

  /// Ordered exterior frames from a provider's compatible 360 view asset.
  final List<CarImage> spinImages;
  final List<CarVariant> variants;

  /// How many variants exist in total, when more were sent than shown.
  final int variantCount;

  final List<String> features;
  final int featureCount;

  final List<CarSpecRow> engineSpecs;
  final List<CarSpecRow> dimensions;
  final List<CarSpecSection> specificationSections;

  /// Listing attributes, used instead of sections for used cars.
  final List<CarSpecRow> overview;

  final String? moreInfoUrl;

  /// Provider or local fallback marker, when supplied by the backend.
  final String? catalogOrigin;

  String get sourceLabel => switch (source) {
    'new' => 'New car',
    'used' => 'Used car',
    _ => 'Car',
  };

  HyderabadPriceEstimate? get onRoadEstimate => source == 'new'
      ? HyderabadPriceEstimate.forNewCar(
          price: price,
          priceLabel: priceRange ?? priceLabel,
          fuelType:
              fuelType ?? (fuelTypes.length == 1 ? fuelTypes.single : null),
        )
      : null;

  /// New car figures are estimated from published ex-showroom prices; used
  /// listings keep the actual seller asking price.
  String get formattedPrice => source == 'new'
      ? onRoadEstimate?.label ?? 'On-road estimate unavailable'
      : priceLabel ?? 'Price on request';

  String get priceHeading => source == 'new'
      ? 'Estimated Hyderabad on-road price'
      : 'Hyderabad asking price';

  int? get financeAmount => source == 'new' ? onRoadEstimate?.minimum : price;

  bool get priceAvailable => source == 'new'
      ? onRoadEstimate != null
      : priceLabel != null || price != null;

  bool get hasGallery => images.isNotEmpty;

  /// Short facts shown in the spec strip under the price.
  List<CarSpecRow> get keyFacts => <CarSpecRow>[
    if (bodyType != null) CarSpecRow(label: 'Body', value: bodyType!),
    if (fuelType != null)
      CarSpecRow(label: 'Fuel', value: fuelType!)
    else if (fuelTypes.isNotEmpty)
      CarSpecRow(label: 'Fuel', value: fuelTypes.join(' / ')),
    if (transmission != null)
      CarSpecRow(label: 'Gearbox', value: transmission!),
    if (mileage != null) CarSpecRow(label: 'Mileage', value: mileage!),
    if (seatingCapacity != null)
      CarSpecRow(label: 'Seats', value: seatingCapacity!),
    if (year != null) CarSpecRow(label: 'Year', value: '$year'),
    if (mileageKm != null) CarSpecRow(label: 'Driven', value: '$mileageKm km'),
    if (city != null) CarSpecRow(label: 'City', value: city!),
    if (owner != null) CarSpecRow(label: 'Ownership', value: owner!),
    if (safetyRating != null) CarSpecRow(label: 'Safety', value: safetyRating!),
  ];

  /// True when a section has enough real content to be worth rendering.
  bool get hasTechnicalSpecs =>
      engineSpecs.isNotEmpty ||
      dimensions.isNotEmpty ||
      specificationSections.isNotEmpty;
}
