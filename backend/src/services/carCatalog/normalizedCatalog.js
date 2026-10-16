/**
 * Normalized local vehicle catalogue.
 *
 * App-owned, provider-independent vehicle layer:
 *
 *  * The external catalogue (CarDekho via Parse) stays PRIMARY whenever it
 *    answers. This layer is the FALLBACK when the external API fails, times
 *    out, returns nothing, or does not carry the vehicle the user asked for
 *    (the popular index has no Kia Sorento, for example).
 *  * Records here are clearly demo data for the local layer only. Values for
 *    *external* catalogue vehicles are never invented - those cards pass
 *    through exactly what the provider published, and anything missing is
 *    rendered by the app as "Not published".
 *  * Cards and details use the same vocabulary as the provider adapter
 *    (`source`, `make`, `formattedPrice`, `detailAvailable`, ...), so the
 *    Flutter DTO, favourites and comparison screens work unchanged.
 *
 * Identifiers: `local-<brand>-<model>` for current records, plus the legacy
 * `fallback-<n>-<n>` ids older favourites may still reference - both resolve
 * forever from this module.
 *
 * Search contract (used by the catalogue service and by AI grounding):
 * case-insensitive, whitespace tolerant, matching brand and/or model words.
 */
import {
  localImageGallery,
  localImageGalleryForTitle,
} from './localVehicleImages.js';

const CURRENCY = 'INR';

/** ₹ formatting identical to the provider adapter, so cards look the same. */
function formatInr(amount) {
  if (amount === null || amount === undefined) return null;
  if (amount >= 10_000_000) return `₹${trimZeros(amount / 10_000_000)} Crore`;
  if (amount >= 100_000) return `₹${trimZeros(amount / 100_000)} Lakh`;

  const digits = String(Math.round(amount));
  const lastThree = digits.slice(-3);
  const rest = digits.slice(0, -3);
  const grouped = rest === '' ? lastThree : `${rest.replace(/\B(?=(\d{2})+(?!\d))/g, ',')},${lastThree}`;
  return `₹${grouped}`;
}

function trimZeros(value) {
  return value.toFixed(2).replace(/\.?0+$/, '');
}

function lakh(value) {
  return Math.round(value * 100_000);
}

function crore(value) {
  return Math.round(value * 10_000_000);
}

/** `₹8.00 - 15.60 Lakh`, or the full form when the units differ. */
function formatRange(min, max) {
  if (min === null || min === undefined) return null;
  if (max === null || max === undefined || max === min) return formatInr(min);

  const unitOf = (amount) =>
    amount >= 10_000_000 ? 'Crore' : amount >= 100_000 ? 'Lakh' : null;
  const minUnit = unitOf(min);
  const maxUnit = unitOf(max);

  if (minUnit !== null && minUnit === maxUnit) {
    const scale = minUnit === 'Crore' ? 10_000_000 : 100_000;
    return `₹${trimZeros(min / scale)} - ${trimZeros(max / scale)} ${minUnit}`;
  }
  return `${formatInr(min)} - ${formatInr(max)}`;
}

/** `Mercedes-Benz` -> `mercedes-benz`; `XUV 700` -> `xuv-700`. */
export function slugify(value) {
  return String(value ?? '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

/**
 * Query words, lowercased, punctuation- and whitespace-tolerant.
 * `  Kia   SORENTO ` -> `['kia', 'sorento']`; `xuv-700` stays one token.
 */
export function tokenizeQuery(query) {
  return String(query ?? '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .filter((token) => token.length >= 2);
}

// ---------------------------------------------------------------------------
// Demo vehicle data - local fallback only.
// ---------------------------------------------------------------------------

const n = (spec) => ({ source: 'new', ...spec });
const u = (spec) => ({ source: 'used', ...spec });

const NEW_VEHICLES = [
  // --- Tata -----------------------------------------------------------------
  n({
    brand: 'Tata', model: 'Nexon',
    min: lakh(7.39), max: lakh(14.39),
    body: 'Compact SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    // Curated demo price snapshot (V3Cars, 2026-07-02); live provider credits
    // are required for a fresh, complete trim list.
    variants: [
      { name: 'Nexon Smart 1.2L Turbo Petrol 5MT', price: 739000, priceLabel: '₹7.39 Lakh', fuelType: 'Petrol', summary: '120 PS, 5-speed manual' },
      { name: 'Nexon Smart Plus 1.2L Turbo Petrol 5MT', price: 821000, priceLabel: '₹8.21 Lakh', fuelType: 'Petrol', summary: '120 PS, 5-speed manual' },
      { name: 'Nexon Fearless Plus PS Red Dark 1.5L Diesel AMT', price: 1439000, priceLabel: '₹14.39 Lakh', fuelType: 'Diesel', summary: 'Diesel, automatic' },
    ],
    seats: 5, mileage: '17.0 - 21.2 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1199 cc turbo', power: '118 bhp', torque: '170 Nm' },
    dims: { length: '3995 mm', width: '1804 mm', height: '1620 mm', wheelbase: '2498 mm', boot: '382 litres' },
    features: ['Electric sunroof', '6 airbags', '10.25-inch touchscreen', 'Ventilated front seats', 'Cruise control', 'Automatic climate control'],
  }),
  n({
    brand: 'Tata', model: 'Punch',
    min: lakh(6.13), max: lakh(10.0),
    body: 'Micro SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '18.5 - 20.1 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1199 cc', power: '87 bhp', torque: '115 Nm' },
    dims: { length: '3758 mm', width: '1635 mm', height: '1607 mm', wheelbase: '2445 mm', boot: '366 litres' },
    features: ['9.2-inch touchscreen', '6 airbags', 'Automatic climate control', 'Projector headlamps', 'Roof rails'],
  }),
  n({
    brand: 'Tata', model: 'Harrier',
    min: lakh(15.49), max: lakh(26.44),
    body: 'SUV', fuels: ['Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '16.1 - 17.5 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1956 cc', power: '168 bhp', torque: '350 Nm' },
    dims: { length: '4595 mm', width: '1894 mm', height: '1706 mm', wheelbase: '2741 mm', boot: '407 litres' },
    features: ['12.3-inch touchscreen', 'Panoramic sunroof', '6 airbags', 'Ventilated front seats', 'ADAS', 'JBL audio'],
  }),
  n({
    brand: 'Tata', model: 'Safari',
    min: lakh(16.19), max: lakh(27.34),
    body: 'SUV', fuels: ['Diesel'], tx: 'Manual & Automatic',
    seats: 7, mileage: '16.1 - 17.5 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1956 cc', power: '168 bhp', torque: '350 Nm' },
    dims: { length: '4661 mm', width: '1894 mm', height: '1786 mm', wheelbase: '2741 mm', boot: '450 litres' },
    features: ['12.3-inch touchscreen', 'Panoramic sunroof', '6 airbags', 'Captain seats', 'ADAS', 'JBL audio'],
  }),
  n({
    brand: 'Tata', model: 'Tiago',
    min: lakh(5.0), max: lakh(7.9),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '19.5 - 23.8 kmpl', safety: '4-star Global NCAP',
    engine: { cc: '1199 cc', power: '85 bhp', torque: '113 Nm' },
    dims: { length: '3765 mm', width: '1677 mm', height: '1535 mm', wheelbase: '2400 mm', boot: '244 litres' },
    features: ['7-inch touchscreen', 'Harman audio', 'Automatic climate control', 'Dual airbags', 'Rear parking camera'],
  }),
  n({
    brand: 'Tata', model: 'Nexon EV',
    min: lakh(14.49), max: lakh(19.49),
    body: 'Compact SUV', fuels: ['Electric'], tx: 'Automatic',
    seats: 5, mileage: '325 - 465 km per charge',
    engine: { cc: 'Permanent magnet AC motor', power: '141 bhp', torque: '210 Nm' },
    dims: { length: '3995 mm', width: '1804 mm', height: '1620 mm', wheelbase: '2498 mm', boot: '350 litres' },
    features: ['45.2 kWh battery', 'DC fast charging', 'Electric sunroof', '10.25-inch touchscreen', 'Ventilated front seats', '6 airbags'],
  }),

  // --- Hyundai -------------------------------------------------------------
  n({
    brand: 'Hyundai', model: 'Creta',
    min: lakh(11.0), max: lakh(20.4),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '15.4 - 17.4 kmpl',
    engine: { cc: '1482 cc', power: '111 bhp', torque: '147 Nm' },
    dims: { length: '4330 mm', width: '1790 mm', height: '1635 mm', wheelbase: '2610 mm', boot: '433 litres' },
    features: ['10.25-inch touchscreen', 'Panoramic sunroof', '6 airbags', 'Ventilated front seats', 'ADAS', 'Bose audio'],
  }),
  n({
    brand: 'Hyundai', model: 'Venue',
    min: lakh(7.94), max: lakh(13.53),
    body: 'Sub-compact SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 21.0 kmpl',
    engine: { cc: '1197 cc', power: '82 bhp', torque: '114 Nm' },
    dims: { length: '3995 mm', width: '1770 mm', height: '1617 mm', wheelbase: '2500 mm', boot: '350 litres' },
    features: ['8-inch touchscreen', 'Electric sunroof', '6 airbags', 'Wireless Android Auto', 'Automatic climate control'],
  }),
  n({
    brand: 'Hyundai', model: 'i20',
    min: lakh(7.04), max: lakh(11.21),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 20.3 kmpl',
    engine: { cc: '1197 cc', power: '87 bhp', torque: '114 Nm' },
    dims: { length: '3990 mm', width: '1775 mm', height: '1505 mm', wheelbase: '2580 mm', boot: '311 litres' },
    features: ['10.25-inch touchscreen', 'Electric sunroof', '6 airbags', 'Wireless charging', 'Digital instrument cluster'],
  }),
  n({
    brand: 'Hyundai', model: 'Verna',
    min: lakh(11.07), max: lakh(17.58),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 20.0 kmpl',
    engine: { cc: '1482 cc', power: '115 bhp', torque: '144 Nm' },
    dims: { length: '4535 mm', width: '1765 mm', height: '1475 mm', wheelbase: '2670 mm', boot: '493 litres' },
    features: ['10.25-inch touchscreen', 'Ventilated front seats', '6 airbags', 'ADAS', 'Electric sunroof', 'Wireless charging'],
  }),
  n({
    brand: 'Hyundai', model: 'Alcazar',
    min: lakh(16.76), max: lakh(21.71),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 6, mileage: '15.0 - 20.1 kmpl',
    engine: { cc: '1493 cc', power: '113 bhp', torque: '250 Nm' },
    dims: { length: '4605 mm', width: '1800 mm', height: '1710 mm', wheelbase: '2770 mm' },
    features: ['Panoramic sunroof', '10.25-inch touchscreen', 'Ventilated front seats', 'Boss mode', '6 airbags', 'ADAS'],
  }),

  // --- Kia -----------------------------------------------------------------
  n({
    brand: 'Kia', model: 'Seltos',
    min: lakh(10.99), max: lakh(20.49),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '16.0 - 20.8 kmpl',
    engine: { cc: '1493 cc', power: '114 bhp', torque: '250 Nm' },
    dims: { length: '4365 mm', width: '1800 mm', height: '1645 mm', wheelbase: '2610 mm', boot: '433 litres' },
    features: ['10.25-inch touchscreen', 'ADAS', 'Ventilated front seats', '6 airbags', 'Electric sunroof', '360-degree camera'],
  }),
  n({
    brand: 'Kia', model: 'Sonet',
    min: lakh(7.99), max: lakh(15.7),
    body: 'Sub-compact SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 21.0 kmpl',
    engine: { cc: '1493 cc', power: '114 bhp', torque: '250 Nm' },
    dims: { length: '3995 mm', width: '1790 mm', height: '1642 mm', wheelbase: '2500 mm', boot: '385 litres' },
    features: ['10.25-inch touchscreen', 'Ventilated front seats', 'Electric sunroof', '6 airbags', 'ADAS', 'Bose audio'],
  }),
  n({
    brand: 'Kia', model: 'Sorento',
    min: lakh(32.0), max: lakh(42.0),
    body: 'SUV', fuels: ['Diesel'], tx: 'Automatic',
    seats: 7, mileage: '13.0 - 17.0 kmpl',
    engine: { cc: '2151 cc', power: '197 bhp', torque: '441 Nm' },
    dims: { length: '4810 mm', width: '1800 mm', height: '1735 mm', wheelbase: '2780 mm' },
    features: ['12.3-inch touchscreen', 'Panoramic sunroof', 'ADAS', 'Ventilated front seats', 'Premium audio', 'Power tailgate'],
  }),
  n({
    brand: 'Kia', model: 'Carens',
    min: lakh(10.99), max: lakh(19.99),
    body: 'MPV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 7, mileage: '15.0 - 17.0 kmpl',
    engine: { cc: '1493 cc', power: '114 bhp', torque: '250 Nm' },
    dims: { length: '4540 mm', width: '1800 mm', height: '1708 mm', wheelbase: '2780 mm' },
    features: ['10.25-inch touchscreen', 'Ventilated front seats', 'Electric sunroof', '6 airbags', 'Ambient lighting', 'Air purifier'],
  }),

  // --- Mahindra ------------------------------------------------------------
  n({
    brand: 'Mahindra', model: 'XUV700',
    min: lakh(14.49), max: lakh(27.99),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 7, mileage: '15.0 - 17.0 kmpl', safety: '5-star Global NCAP (adult)',
    engine: { cc: '2198 cc', power: '182 bhp', torque: '450 Nm' },
    dims: { length: '4695 mm', width: '1890 mm', height: '1755 mm', wheelbase: '2750 mm' },
    features: ['Panoramic sunroof', '10.25-inch touchscreen', 'ADAS', 'Ventilated front seats', '6 airbags', 'Sony audio'],
  }),
  n({
    brand: 'Mahindra', model: 'Scorpio-N',
    min: lakh(13.26), max: lakh(24.54),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 7, mileage: '15.0 - 18.0 kmpl',
    engine: { cc: '2184 cc', power: '172 bhp', torque: '400 Nm' },
    dims: { length: '4745 mm', width: '1985 mm', height: '1870 mm', wheelbase: '2750 mm' },
    features: ['Electric sunroof', '6 airbags', '8-inch touchscreen', 'Sony audio', 'Cruise control', 'Automatic climate control'],
  }),
  n({
    brand: 'Mahindra', model: 'Thar',
    min: lakh(11.35), max: lakh(17.6),
    body: 'Off-road SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 4, mileage: '15.0 - 16.0 kmpl', safety: '4-star Global NCAP',
    engine: { cc: '2184 cc', power: '148 bhp', torque: '300 Nm' },
    dims: { length: '3985 mm', width: '1820 mm', height: '1844 mm', wheelbase: '2450 mm' },
    features: ['4x4 with low range', '7-inch touchscreen', 'Cruise control', 'Convertible hard top', 'Tyre pressure monitoring'],
  }),
  n({
    brand: 'Mahindra', model: 'XUV 3XO',
    min: lakh(7.99), max: lakh(15.49),
    body: 'Sub-compact SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 21.0 kmpl',
    engine: { cc: '1197 cc turbo', power: '129 bhp', torque: '230 Nm' },
    dims: { length: '3995 mm', width: '1821 mm', height: '1627 mm', wheelbase: '2600 mm', boot: '364 litres' },
    features: ['Panoramic sunroof', '10.25-inch touchscreen', 'ADAS', 'Ventilated front seats', '6 airbags', 'Wireless Android Auto'],
  }),

  // --- Toyota --------------------------------------------------------------
  n({
    brand: 'Toyota', model: 'Fortuner',
    min: lakh(33.43), max: crore(5.144),
    body: 'SUV', fuels: ['Diesel'], tx: 'Automatic',
    seats: 7, mileage: '14.0 - 16.8 kmpl',
    engine: { cc: '2755 cc', power: '163 bhp', torque: '500 Nm' },
    dims: { length: '4795 mm', width: '1855 mm', height: '1835 mm', wheelbase: '2745 mm' },
    features: ['8-inch touchscreen', '7 seats', '4x4 with crawl control', 'JBL audio', 'Ventilated front seats', 'Cruise control'],
  }),
  n({
    brand: 'Toyota', model: 'Innova Crysta',
    min: lakh(19.99), max: lakh(26.3),
    body: 'MPV', fuels: ['Diesel'], tx: 'Manual',
    seats: 7, mileage: '15.0 - 16.2 kmpl',
    engine: { cc: '2393 cc', power: '148 bhp', torque: '343 Nm' },
    dims: { length: '4735 mm', width: '1830 mm', height: '1795 mm', wheelbase: '2750 mm', boot: '300 litres' },
    features: ['8-inch touchscreen', 'Captain seats', 'Automatic climate control', 'Rear AC vents', 'Dual airbags', 'Power steering'],
  }),
  n({
    brand: 'Toyota', model: 'Urban Cruiser Hyryder',
    min: lakh(11.14), max: lakh(20.52),
    body: 'SUV', fuels: ['Petrol', 'Hybrid'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 27.9 kmpl',
    engine: { cc: '1462 cc', power: '114 bhp', torque: '136 Nm' },
    dims: { length: '4365 mm', width: '1795 mm', height: '1645 mm', wheelbase: '2600 mm', boot: '373 litres' },
    features: ['9-inch touchscreen', 'Strong hybrid powertrain', 'Electric sunroof', 'Head-up display', 'Wireless Android Auto'],
  }),
  n({
    brand: 'Toyota', model: 'Glanza',
    min: lakh(7.6), max: lakh(10.4),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '22.0 - 24.0 kmpl',
    engine: { cc: '1197 cc', power: '88 bhp', torque: '114 Nm' },
    dims: { length: '3990 mm', width: '1745 mm', height: '1470 mm', wheelbase: '2520 mm', boot: '318 litres' },
    features: ['9-inch touchscreen', 'Head-up display', '360-degree camera', 'LED headlamps', 'Automatic climate control'],
  }),

  // --- Honda ---------------------------------------------------------------
  n({
    brand: 'Honda', model: 'City',
    min: lakh(11.0), max: lakh(16.5),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '18.0 - 26.1 kmpl',
    engine: { cc: '1498 cc', power: '119 bhp', torque: '145 Nm' },
    dims: { length: '4574 mm', width: '1748 mm', height: '1489 mm', wheelbase: '2600 mm', boot: '506 litres' },
    features: ['8-inch touchscreen', 'Honda Sensing ADAS', 'Electric sunroof', 'Ventilated front seats', '6 airbags'],
  }),
  n({
    brand: 'Honda', model: 'Elevate',
    min: lakh(11.0), max: lakh(15.5),
    body: 'SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '15.3 - 16.9 kmpl',
    engine: { cc: '1498 cc', power: '119 bhp', torque: '145 Nm' },
    dims: { length: '4312 mm', width: '1790 mm', height: '1610 mm', wheelbase: '2650 mm' },
    features: ['8-inch touchscreen', 'Honda Sensing ADAS', 'Electric sunroof', 'Wireless Android Auto', 'LED headlamps'],
  }),
  n({
    brand: 'Honda', model: 'Amaze',
    min: lakh(7.99), max: lakh(11.5),
    body: 'Compact sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '18.0 - 21.0 kmpl',
    engine: { cc: '1199 cc', power: '89 bhp', torque: '110 Nm' },
    dims: { length: '3995 mm', width: '1734 mm', height: '1503 mm', wheelbase: '2470 mm' },
    features: ['8-inch touchscreen', 'Lane watch camera', 'Automatic climate control', 'Dual airbags', 'Rear parking camera'],
  }),

  // --- Maruti Suzuki -------------------------------------------------------
  n({
    brand: 'Maruti Suzuki', model: 'Swift',
    min: lakh(6.49), max: lakh(9.65),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '22.0 - 24.5 kmpl',
    engine: { cc: '1197 cc', power: '81 bhp', torque: '112 Nm' },
    dims: { length: '3860 mm', width: '1735 mm', height: '1520 mm', wheelbase: '2450 mm', boot: '265 litres' },
    features: ['9-inch SmartPlay touchscreen', 'Head-up display', '6 airbags', 'Automatic climate control', 'Wireless Android Auto'],
  }),
  n({
    brand: 'Maruti Suzuki', model: 'Baleno',
    min: lakh(6.66), max: lakh(9.83),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '22.0 - 24.5 kmpl',
    engine: { cc: '1197 cc', power: '88 bhp', torque: '114 Nm' },
    dims: { length: '3990 mm', width: '1745 mm', height: '1500 mm', wheelbase: '2520 mm', boot: '318 litres' },
    features: ['9-inch SmartPlay touchscreen', 'Head-up display', '360-degree camera', '6 airbags', 'Wireless charging'],
  }),
  n({
    brand: 'Maruti Suzuki', model: 'Brezza',
    min: lakh(8.34), max: lakh(14.14),
    body: 'Compact SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 19.8 kmpl',
    engine: { cc: '1462 cc', power: '102 bhp', torque: '137 Nm' },
    dims: { length: '3995 mm', width: '1790 mm', height: '1685 mm', wheelbase: '2500 mm', boot: '328 litres' },
    features: ['9-inch SmartPlay touchscreen', 'Electric sunroof', '6 airbags', 'Head-up display', 'Wireless Android Auto'],
  }),
  n({
    brand: 'Maruti Suzuki', model: 'Fronx',
    min: lakh(7.51), max: lakh(13.03),
    body: 'Crossover', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '20.0 - 22.9 kmpl',
    engine: { cc: '1197 cc turbo', power: '99 bhp', torque: '147 Nm' },
    dims: { length: '3995 mm', width: '1765 mm', height: '1550 mm', wheelbase: '2520 mm', boot: '308 litres' },
    features: ['9-inch SmartPlay touchscreen', 'Head-up display', '6 airbags', 'Wireless Android Auto', 'Automatic climate control'],
  }),
  n({
    brand: 'Maruti Suzuki', model: 'Ertiga',
    min: lakh(8.69), max: lakh(13.03),
    body: 'MPV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 7, mileage: '18.0 - 20.3 kmpl',
    engine: { cc: '1462 cc', power: '102 bhp', torque: '137 Nm' },
    dims: { length: '4395 mm', width: '1735 mm', height: '1690 mm', wheelbase: '2740 mm', boot: '209 litres' },
    features: ['7-inch touchscreen', '7 seats', 'Rear AC vents', 'Automatic climate control', 'Dual airbags'],
  }),
  n({
    brand: 'Maruti Suzuki', model: 'Dzire',
    min: lakh(6.84), max: lakh(10.14),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '22.0 - 24.5 kmpl',
    engine: { cc: '1197 cc', power: '81 bhp', torque: '112 Nm' },
    dims: { length: '3990 mm', width: '1735 mm', height: '1515 mm', wheelbase: '2450 mm', boot: '382 litres' },
    features: ['9-inch SmartPlay touchscreen', 'Head-up display', '6 airbags', 'Wireless Android Auto', 'Automatic climate control'],
  }),

  // --- Volkswagen ----------------------------------------------------------
  n({
    brand: 'Volkswagen', model: 'Virtus',
    min: lakh(11.7), max: lakh(19.0),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '18.0 - 20.0 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1498 cc turbo', power: '148 bhp', torque: '250 Nm' },
    dims: { length: '4561 mm', width: '1752 mm', height: '1469 mm', wheelbase: '2651 mm', boot: '521 litres' },
    features: ['10-inch touchscreen', 'Ventilated front seats', '6 airbags', 'Wireless Android Auto', 'Cruise control'],
  }),
  n({
    brand: 'Volkswagen', model: 'Taigun',
    min: lakh(11.7), max: lakh(19.1),
    body: 'SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 19.0 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1498 cc turbo', power: '148 bhp', torque: '250 Nm' },
    dims: { length: '4236 mm', width: '1841 mm', height: '1634 mm', wheelbase: '2651 mm', boot: '385 litres' },
    features: ['10-inch touchscreen', 'Ventilated front seats', '6 airbags', 'Sunroof', 'Wireless Android Auto'],
  }),

  // --- Skoda ----------------------------------------------------------------
  n({
    brand: 'Skoda', model: 'Kushaq',
    min: lakh(10.99), max: lakh(18.79),
    body: 'SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '17.0 - 19.0 kmpl', safety: '5-star Global NCAP',
    engine: { cc: '1498 cc turbo', power: '148 bhp', torque: '250 Nm' },
    dims: { length: '4225 mm', width: '1760 mm', height: '1612 mm', wheelbase: '2651 mm', boot: '385 litres' },
    features: ['10-inch touchscreen', 'Ventilated front seats', '6 airbags', 'Sunroof', 'Wireless Android Auto'],
  }),
  n({
    brand: 'Skoda', model: 'Slavia',
    min: lakh(10.99), max: lakh(18.45),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '18.0 - 20.0 kmpl',
    engine: { cc: '1498 cc turbo', power: '148 bhp', torque: '250 Nm' },
    dims: { length: '4541 mm', width: '1752 mm', height: '1487 mm', wheelbase: '2651 mm', boot: '521 litres' },
    features: ['10-inch touchscreen', 'Ventilated front seats', '6 airbags', 'Sunroof', 'Wireless Android Auto'],
  }),

  // --- MG ------------------------------------------------------------------
  n({
    brand: 'MG', model: 'Hector',
    min: lakh(15.0), max: lakh(24.0),
    body: 'SUV', fuels: ['Petrol', 'Diesel'], tx: 'Manual & Automatic',
    seats: 7, mileage: '14.0 - 17.0 kmpl',
    engine: { cc: '1451 cc turbo', power: '141 bhp', torque: '250 Nm' },
    dims: { length: '4698 mm', width: '1835 mm', height: '1760 mm', wheelbase: '2750 mm', boot: '507 litres' },
    features: ['14-inch touchscreen', 'Panoramic sunroof', 'ADAS', 'Ventilated front seats', '6 airbags'],
  }),
  n({
    brand: 'MG', model: 'Astor',
    min: lakh(11.0), max: lakh(17.0),
    body: 'SUV', fuels: ['Petrol'], tx: 'Manual & Automatic',
    seats: 5, mileage: '15.0 - 17.0 kmpl',
    engine: { cc: '1498 cc', power: '108 bhp', torque: '144 Nm' },
    dims: { length: '4323 mm', width: '1809 mm', height: '1653 mm', wheelbase: '2580 mm', boot: '470 litres' },
    features: ['10.4-inch touchscreen', 'Panoramic sunroof', 'ADAS', 'Ventilated front seats', '6 airbags'],
  }),

  // --- BMW -----------------------------------------------------------------
  n({
    brand: 'BMW', model: '3 Series',
    min: lakh(71.9), max: lakh(87.5),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Automatic',
    seats: 5, mileage: '15.0 - 16.0 kmpl',
    engine: { cc: '1998 cc turbo', power: '255 bhp', torque: '400 Nm' },
    dims: { length: '4713 mm', width: '1827 mm', height: '1440 mm', wheelbase: '2851 mm' },
    features: ['Curved display', 'Panoramic sunroof', 'Harman Kardon audio', 'Wireless Apple CarPlay', 'Adaptive LED headlamps'],
  }),
  n({
    brand: 'BMW', model: 'X1',
    min: lakh(46.9), max: lakh(56.0),
    body: 'SUV', fuels: ['Petrol'], tx: 'Automatic',
    seats: 5, mileage: '15.0 - 17.0 kmpl',
    engine: { cc: '1499 cc turbo', power: '134 bhp', torque: '240 Nm' },
    dims: { length: '4500 mm', width: '1845 mm', height: '1642 mm', wheelbase: '2692 mm', boot: '540 litres' },
    features: ['Panoramic sunroof', 'Curved display', 'Harman Kardon audio', 'Wireless charging', 'Adaptive LED headlamps'],
  }),
  n({
    brand: 'BMW', model: 'X5',
    min: lakh(97.5), max: crore(11.0),
    body: 'SUV', fuels: ['Diesel'], tx: 'Automatic',
    seats: 5, mileage: '13.0 - 15.0 kmpl',
    engine: { cc: '2993 cc', power: '282 bhp', torque: '650 Nm' },
    dims: { length: '4922 mm', width: '2004 mm', height: '1745 mm', wheelbase: '2975 mm' },
    features: ['Panoramic sunroof', 'Bowers & Wilkins audio', 'Air suspension', 'Head-up display', 'Adaptive LED headlamps'],
  }),

  // --- Mercedes-Benz -------------------------------------------------------
  n({
    brand: 'Mercedes-Benz', model: 'C-Class',
    min: lakh(60.0), max: lakh(78.0),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Automatic',
    seats: 5, mileage: '14.0 - 16.0 kmpl',
    engine: { cc: '1497 cc turbo', power: '197 bhp', torque: '300 Nm' },
    dims: { length: '4751 mm', width: '1820 mm', height: '1438 mm', wheelbase: '2865 mm' },
    features: ['MBUX infotainment', 'Panoramic sunroof', 'Burmester audio', 'Wireless charging', 'Ambient lighting'],
  }),
  n({
    brand: 'Mercedes-Benz', model: 'GLC',
    min: lakh(73.0), max: lakh(88.0),
    body: 'SUV', fuels: ['Petrol'], tx: 'Automatic',
    seats: 5, mileage: '13.0 - 15.0 kmpl',
    engine: { cc: '1993 cc turbo', power: '197 bhp', torque: '320 Nm' },
    dims: { length: '4716 mm', width: '1890 mm', height: '1640 mm', wheelbase: '2888 mm', boot: '550 litres' },
    features: ['MBUX infotainment', 'Panoramic sunroof', 'Burmester audio', 'Ambient lighting', 'Wireless charging'],
  }),
  n({
    brand: 'Mercedes-Benz', model: 'GLE',
    min: lakh(90.0), max: crore(11.5),
    body: 'SUV', fuels: ['Diesel'], tx: 'Automatic',
    seats: 7, mileage: '12.0 - 14.0 kmpl',
    engine: { cc: '2989 cc', power: '345 bhp', torque: '700 Nm' },
    dims: { length: '4924 mm', width: '2018 mm', height: '1782 mm', wheelbase: '2995 mm' },
    features: ['MBUX infotainment', 'Panoramic sunroof', 'Burmester audio', 'Air suspension', 'Head-up display'],
  }),
];

const USED_VEHICLES = [
  // Legacy ids (fallback-used-*) are kept so favourites saved against the old
  // fallback catalogue keep resolving.
  u({
    legacyId: 'fallback-used-1',
    brand: 'BMW', model: 'M2', title: 'BMW M2 Coupe',
    price: crore(1.07),
    body: 'Coupe', fuels: ['Petrol'], tx: 'Automatic', seats: 4,
    year: 2024, km: 5800, city: 'Gurgaon', owner: 'First owner',
    engine: { cc: '2993 cc turbo', power: '453 bhp', torque: '550 Nm' },
    features: ['M sport seats', 'Harman Kardon audio', 'Head-up display', 'Adaptive LED headlamps'],
  }),
  u({
    legacyId: 'fallback-used-2',
    brand: 'Audi', model: 'Q5', title: 'Audi Q5 Premium',
    price: lakh(54.0),
    body: 'SUV', fuels: ['Petrol'], tx: 'Automatic', seats: 5,
    year: 2023, km: 7100, city: 'New Delhi', owner: 'First owner',
    engine: { cc: '1984 cc turbo', power: '248 bhp', torque: '370 Nm' },
    features: ['Virtual cockpit', 'Panoramic sunroof', 'Bang & Olufsen audio', 'Wireless charging'],
  }),
  u({
    brand: 'Mercedes-Benz', model: 'C-Class', title: 'Mercedes-Benz C 200 Progressive',
    price: lakh(42.5),
    body: 'Sedan', fuels: ['Petrol'], tx: 'Automatic', seats: 5,
    year: 2022, km: 18500, city: 'Mumbai', owner: 'First owner',
    engine: { cc: '1497 cc turbo', power: '197 bhp', torque: '300 Nm' },
    features: ['MBUX infotainment', 'Panoramic sunroof', 'Burmester audio', 'Ambient lighting'],
  }),
  u({
    brand: 'Toyota', model: 'Innova Crysta', title: 'Toyota Innova Crysta ZX',
    price: lakh(22.0),
    body: 'MPV', fuels: ['Diesel'], tx: 'Manual', seats: 7,
    year: 2021, km: 48000, city: 'Bangalore', owner: 'Second owner',
    engine: { cc: '2393 cc', power: '148 bhp', torque: '343 Nm' },
    features: ['Captain seats', 'Automatic climate control', 'Touchscreen infotainment', 'Rear AC vents'],
  }),
  u({
    brand: 'Hyundai', model: 'Creta', title: 'Hyundai Creta SX Turbo',
    price: lakh(14.75),
    body: 'SUV', fuels: ['Petrol'], tx: 'Automatic', seats: 5,
    year: 2022, km: 26400, city: 'New Delhi', owner: 'First owner',
    engine: { cc: '1591 cc turbo', power: '138 bhp', torque: '172 Nm' },
    features: ['Panoramic sunroof', 'Ventilated front seats', 'Air purifier', 'Wireless charging'],
  }),
  u({
    brand: 'Skoda', model: 'Kushaq', title: 'Skoda Kushaq Style',
    price: lakh(13.2),
    body: 'SUV', fuels: ['Petrol'], tx: 'Manual', seats: 5,
    year: 2023, km: 15200, city: 'Mumbai', owner: 'First owner',
    engine: { cc: '1498 cc turbo', power: '148 bhp', torque: '250 Nm' },
    features: ['Sunroof', 'Ventilated front seats', 'Touchscreen infotainment', 'Cruise control'],
  }),
  u({
    brand: 'Maruti Suzuki', model: 'Baleno', title: 'Maruti Suzuki Baleno Alpha',
    price: lakh(7.4),
    body: 'Hatchback', fuels: ['Petrol'], tx: 'Manual', seats: 5,
    year: 2022, km: 21000, city: 'New Delhi', owner: 'First owner',
    engine: { cc: '1197 cc', power: '88 bhp', torque: '114 Nm' },
    features: ['Head-up display', '360-degree camera', 'SmartPlay Pro touchscreen', 'Automatic climate control'],
  }),
];

// ---------------------------------------------------------------------------
// Normalization: raw spec -> provider-shaped card and detail records.
// ---------------------------------------------------------------------------

/** Ids minted by the previous fallback catalogue, by vehicle identity. */
const LEGACY_NEW_IDS = new Map([
  ['tata|nexon', 'fallback-new-1'],
  ['hyundai|creta', 'fallback-new-2'],
  ['mahindra|xuv700', 'fallback-new-3'],
]);

/** `tata` + `nexon` -> `tata|nexon`. Stable across spellings (`XUV 3XO`). */
function identityOf(brand, model) {
  return `${slugify(brand)}|${slugify(model)}`;
}

function idOf(record, identity) {
  if (record.source === 'new') {
    const legacy = LEGACY_NEW_IDS.get(identity);
    if (legacy !== undefined) return legacy;
  }
  if (record.legacyId !== undefined) return record.legacyId;
  return `local-${slugify(record.brand)}-${slugify(record.model)}`;
}

function prepare(vehicle) {
  const identity = identityOf(vehicle.brand, vehicle.model);
  const isUsed = vehicle.source === 'used';
  const title = vehicle.title ?? `${vehicle.brand} ${vehicle.model}`;
  const price = isUsed ? vehicle.price : vehicle.min;
  const formattedPrice = isUsed ? formatInr(vehicle.price) : formatRange(vehicle.min, vehicle.max);
  const galleryImages = vehicle.galleryImages ?? localImageGallery(vehicle.brand, vehicle.model);
  const imageUrl = vehicle.imageUrl ?? galleryImages[0]?.url ?? null;

  return {
    ...vehicle,
    galleryImages,
    imageUrl,
    identity,
    id: idOf(vehicle, identity),
    title,
    price: price ?? null,
    formattedPrice,
  };
}

const RECORDS = [...NEW_VEHICLES, ...USED_VEHICLES].map(prepare);

const BY_ID = new Map(RECORDS.map((record) => [record.id, record]));
const BY_IDENTITY = new Map(RECORDS.map((record) => [record.identity, record]));

/** Cards match the provider adapter's card vocabulary exactly. */
function toCard(record) {
  return {
    id: record.id,
    source: record.source,
    title: record.title,
    brand: record.brand,
    make: record.brand,
    model: record.model,
    variant: null,
    year: record.year ?? null,
    price: record.price ?? null,
    formattedPrice: record.formattedPrice,
    currency: CURRENCY,
    bodyType: record.body ?? null,
    fuelType: record.fuels?.[0] ?? null,
    transmission: record.tx ?? null,
    mileageKm: record.km ?? null,
    city: record.city ?? null,
    owner: record.owner ?? null,
    imageUrl: record.imageUrl ?? null,
    detailAvailable: true,
    catalogOrigin: 'local_demo',
  };
}

const DIMENSION_LABELS = {
  length: 'Length',
  width: 'Width',
  height: 'Height',
  wheelbase: 'Wheelbase',
  boot: 'Boot space',
};

function labelValueRows(source, labels) {
  if (source === null || typeof source !== 'object') return [];
  return Object.entries(source)
    .map(([key, value]) => ({ label: labels[key] ?? key, value: String(value) }))
    .filter((row) => row.value !== '');
}

/** Full detail, shaped exactly like the provider adapter's detail response. */
function toDetail(record) {
  const isUsed = record.source === 'used';
  const features = record.features ?? [];

  const overview = [];
  const add = (label, value) => {
    if (value !== null && value !== undefined && value !== '') {
      overview.push({ label, value: String(value) });
    }
  };
  add('Body type', record.body ?? null);
  add('Seating', record.seats ?? null);
  add('Fuel type', record.fuels?.length ? record.fuels.join(' / ') : null);
  add('Transmission', record.tx ?? null);
  if (!isUsed) add('Mileage', record.mileage ?? null);
  add('Year', record.year ?? null);
  if (isUsed) add('Kilometers driven', record.km != null ? `${record.km} km` : null);
  add('Safety rating', record.safety ?? null);
  add('City', record.city ?? null);
  add('Ownership', record.owner ?? null);

  return {
    id: record.id,
    source: record.source,
    title: record.title,
    brand: record.brand,
    make: record.brand,
    model: record.model,
    variant: null,
    year: record.year ?? null,
    price: record.price ?? null,
    formattedPrice: record.formattedPrice,
    priceRange: isUsed ? null : record.formattedPrice,
    currency: CURRENCY,
    bodyType: record.body ?? null,
    fuelType: record.fuels?.[0] ?? null,
    fuelTypes: record.fuels ?? [],
    transmission: record.tx ?? null,
    mileage: isUsed ? null : (record.mileage ?? null),
    safetyRating: record.safety ?? null,
    seatingCapacity: record.seats != null ? String(record.seats) : null,
    mileageKm: record.km ?? null,
    city: record.city ?? null,
    owner: record.owner ?? null,
    images: (record.galleryImages ?? []).map((image) => isUsed
      ? {
          ...image,
          alt: `Representative model photo, not this specific listing: ${record.title}`,
          category: 'model reference',
        }
      : image),
    spinImages: [],
    variants: record.variants ?? [],
    variantCount: record.variants?.length ?? 0,
    features,
    featureCount: features.length,
    engineSpecs: labelValueRows(
      record.engine === undefined ? null : {
        displacement: record.engine.cc,
        power: record.engine.power,
        torque: record.engine.torque,
      },
      { displacement: 'Displacement', power: 'Max power', torque: 'Max torque' },
    ),
    dimensions: labelValueRows(record.dims ?? null, DIMENSION_LABELS),
    specificationSections: [],
    overview,
    moreInfoUrl: null,
    catalogOrigin: 'local_demo',
  };
}

// ---------------------------------------------------------------------------
// Search - case-insensitive, whitespace tolerant, brand + model aware.
// ---------------------------------------------------------------------------

/** `kia` matches Kia; `maruti` matches Maruti Suzuki; `mercedes` matches MB. */
export function matchesBrand(record, brandSlug) {
  if (brandSlug === undefined || brandSlug === null || brandSlug === '') return true;
  const wanted = slugify(brandSlug);
  const make = slugify(record.make ?? record.brand);
  if (make === wanted || make.startsWith(`${wanted}-`)) return true;
  // Cards without a make fall back to the title's leading words.
  const titleLead = slugify(String(record.title ?? '').split(/\s+/).slice(0, 2).join(' '));
  return titleLead === wanted || titleLead.startsWith(`${wanted}-`);
}

/** Every query token must appear in the vehicle's title / brand / model. */
export function matchesTokens(record, tokens) {
  if (tokens === undefined || tokens.length === 0) return true;
  const haystack = `${record.title} ${record.make ?? record.brand ?? ''} ${record.model}`.toLowerCase();
  return tokens.every((token) => haystack.includes(token));
}

/**
 * The local catalogue's search.
 *
 * @param {{ source?: 'new'|'used', brand?: string, q?: string }} [query]
 * @returns {Array<Record<string, unknown>>} provider-shaped cards.
 */
export function searchLocalCars(query = {}) {
  const tokens = tokenizeQuery(query.q);
  return RECORDS.filter(
    (record) =>
      (query.source === undefined || record.source === query.source) &&
      matchesBrand(record, query.brand) &&
      matchesTokens(record, tokens),
  ).map(toCard);
}

/** Detail for a locally minted id (`local-*` or legacy `fallback-*`), else null. */
export function getLocalCarDetail(id) {
  const record = BY_ID.get(typeof id === 'string' ? id : '');
  return record === undefined ? null : toDetail(record);
}

/** True when the id belongs to this catalogue (drives favourites validation). */
export function isLocalCatalogId(id) {
  return typeof id === 'string' && BY_ID.has(id);
}

/**
 * Local substitute for a provider model id whose upstream detail call failed:
 * `tata` + `nexon` -> the local Tata Nexon detail, or null when we carry none.
 */
export function getLocalByBrandModel(brandSlug, modelSlug) {
  const record = BY_IDENTITY.get(identityOf(brandSlug, modelSlug));
  return record === undefined ? null : toDetail(record);
}

/** Known model gallery used to fill missing photos in provider responses. */
export function getLocalImageGallery(brand, model) {
  return localImageGallery(brand, model);
}

/** Model gallery for a known vehicle title, used by image-less used listings. */
export function getLocalImageGalleryForTitle(title) {
  return localImageGalleryForTitle(title);
}

/**
 * Stable merge key so external and local records of the same vehicle collapse
 * into one card: `Mahindra Scorpio N` and `Mahindra Scorpio-N` are one car.
 */
export function dedupKey(car) {
  const make = car.make ?? car.brand ?? String(car.title ?? '').split(/\s+/)[0] ?? '';
  return `${slugify(make)}|${slugify(car.model ?? car.title ?? '')}`;
}

/** Every local record as a card, for building AI catalog indexes. */
export function getLocalCarCards(source) {
  return RECORDS.filter((record) => source === undefined || record.source === source).map(toCard);
}
