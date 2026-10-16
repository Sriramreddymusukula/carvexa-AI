import {
  describeCapabilities,
  getCarDetail,
  listCars,
} from '../services/carCatalog.service.js';

/**
 * HTTP layer for the car catalogue.
 *
 * In/out only: it reads the already-validated request, calls one service
 * function and wraps the result in the API envelope. It never touches the
 * provider, which is what keeps the provider swappable.
 */

/**
 * GET /api/cars
 *
 * Returns catalogue cards plus a `capabilities` block describing what the
 * current source can actually do. The app renders its search box and filters
 * from that block, so a control can never appear that would not change the
 * result set.
 */
export async function listCarsHandler(req, res) {
  const result = await listCars(req.valid.query ?? {});

  res.json({
    data: {
      cars: result.cars,
      source: result.source,
      page: result.page,
      pageSize: result.pageSize,
      hasMore: result.hasMore,
      // False when the provider reports a total that cannot be trusted; the app
      // then shows "load more" rather than inventing a result count.
      totalKnown: result.totalKnown,
      appliedFilters: result.appliedFilters,
      capabilities: result.capabilities,
    },
    // `origin` says honestly which layer answered: `external`, `mixed`
    // (external primary plus local supplement) or `local_fallback`.
    meta: { count: result.cars.length, origin: result.origin ?? 'external' },
  });
}

/**
 * GET /api/cars/capabilities
 *
 * Declared before `/:id` so it is never decoded as a catalogue id. Costs no
 * provider credits, so the app can call it freely on start-up.
 */
export function capabilitiesHandler(_req, res) {
  res.json({ data: describeCapabilities() });
}

/**
 * GET /api/cars/:id
 *
 * The id is opaque and signed; an invalid one is rejected by the service with a
 * 400 before anything is fetched.
 */
export async function carDetailHandler(req, res) {
  const car = await getCarDetail(req.valid.params.id);
  res.json({ data: car });
}
