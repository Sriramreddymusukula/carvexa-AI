// Live verification of the car catalogue, end to end through the real HTTP
// stack: this script -> Express -> the external provider.
//
// Costs a handful of provider credits, so it is a manual command, never part of
// `npm test` (which is fully offline).
//
//   npm run catalog:check
process.env.NODE_ENV = process.env.NODE_ENV ?? 'test';
process.env.LOG_LEVEL = process.env.LOG_LEVEL ?? 'error';
process.env.HTTP_REQUEST_LOGGING = 'false';

const { createApp } = await import('../src/app.js');

const server = createApp().listen(0);
await new Promise((resolve) => server.once('listening', resolve));
const base = `http://127.0.0.1:${server.address().port}`;

const get = async (path) => {
  const response = await fetch(`${base}${path}`);
  let body = null;
  try {
    body = await response.json();
  } catch {
    body = null;
  }
  return { status: response.status, body };
};

const line = (label, value) => console.log(`${label.padEnd(42)} ${value}`);
const failures = [];
const check = (label, condition) => {
  if (!condition) failures.push(label);
};

try {
  const caps = await get('/api/cars/capabilities');
  check('catalog capabilities', caps.status === 200 && caps.body?.data?.ready === true);
  line('capabilities status', caps.status);
  line(
    'capabilities sources',
    (caps.body?.data?.sources ?? []).map((s) => `${s.id}(search=${s.search},page=${s.pagination})`).join(' '),
  );
  line('capabilities defaultSource', caps.body?.data?.defaultSource);

  const used = await get('/api/cars');
  check('used catalog response', used.status === 200 && Array.isArray(used.body?.data?.cars));
  line('USED /api/cars status', used.status);
  line('USED count', used.body?.data?.cars?.length);
  line('USED hasMore', used.body?.data?.hasMore);
  const usedFirst = used.body?.data?.cars?.[0];
  if (usedFirst) {
    line('USED first title', usedFirst.title);
    line('USED first price', `${usedFirst.formattedPrice} (${usedFirst.price})`);
    line('USED first city/owner', `${usedFirst.city} / ${usedFirst.owner}`);
    line('USED first mileageKm', usedFirst.mileageKm);
    line('USED first has image', Boolean(usedFirst.imageUrl));
    line('USED first id length', String(usedFirst.id ?? '').length);
  }

  const fresh = await get('/api/cars?source=new');
  check('new catalog response', fresh.status === 200 && Array.isArray(fresh.body?.data?.cars));
  line('NEW /api/cars status', fresh.status);
  line('NEW count', fresh.body?.data?.cars?.length);
  const newFirst = fresh.body?.data?.cars?.[0];
  if (newFirst) {
    line('NEW first title', newFirst.title);
    line('NEW first make/model', `${newFirst.make} / ${newFirst.model}`);
    line('NEW first price', String(newFirst.formattedPrice));
    line('NEW first has image', Boolean(newFirst.imageUrl));
  }

  const search = await get('/api/cars?source=new&q=tata+nexon');
  check('new catalog search', search.status === 200 && Array.isArray(search.body?.data?.cars));
  line('SEARCH ?q=tata nexon status', search.status);
  line('SEARCH count', search.body?.data?.cars?.length);
  line('SEARCH titles', (search.body?.data?.cars ?? []).map((c) => c.title).slice(0, 6).join(' | '));

  const searchBrand = await get('/api/cars?source=new&brand=tata');
  check('new catalog brand filter', searchBrand.status === 200 && Array.isArray(searchBrand.body?.data?.cars));
  line('NEW brand=tata status', searchBrand.status);
  line('NEW brand=tata count', searchBrand.body?.data?.cars?.length);

  if (newFirst?.id) {
    const detail = await get(`/api/cars/${encodeURIComponent(newFirst.id)}`);
    check('new vehicle detail', detail.status === 200 && detail.body?.data?.id === newFirst.id);
    line('DETAIL status', detail.status);
    const d = detail.body?.data;
    line('DETAIL title', d?.title);
    line('DETAIL priceRange', d?.priceRange);
    line('DETAIL bodyType', d?.bodyType);
    line('DETAIL fuelTypes', (d?.fuelTypes ?? []).join(', '));
    line('DETAIL safetyRating', d?.safetyRating);
    line('DETAIL gallery images', d?.images?.length);
    line('DETAIL variants', `${d?.variants?.length} of ${d?.variantCount}`);
    line('DETAIL features', `${d?.features?.length} of ${d?.featureCount}`);
    line('DETAIL engineSpecs', (d?.engineSpecs ?? []).map((p) => `${p.label}=${p.value}`).join('; '));
    line('DETAIL dimensions', (d?.dimensions ?? []).map((p) => `${p.label}=${p.value}`).join('; '));
    line('DETAIL spec sections', (d?.specificationSections ?? []).map((s) => s.title).join(' | '));
    line('DETAIL first image', String(d?.images?.[0]?.url ?? '').slice(0, 70));
  }

  if (usedFirst?.id) {
    const listing = await get(`/api/cars/${encodeURIComponent(usedFirst.id)}`);
    check('used vehicle detail', listing.status === 200 && listing.body?.data?.id === usedFirst.id);
    const d = listing.body?.data;
    line('LISTING DETAIL status', listing.status);
    line('LISTING DETAIL title', String(d?.title ?? '').slice(0, 70));
    line('LISTING DETAIL price', d?.formattedPrice);
    line('LISTING DETAIL gallery', d?.images?.length);
    line('LISTING DETAIL overview', (d?.overview ?? []).map((o) => `${o.label}=${o.value}`).slice(0, 6).join('; '));
    line('LISTING DETAIL year', d?.year);
  }

  const badId = await get('/api/cars/definitely-not-an-id');
  check('malformed catalog id rejected', badId.status === 400);
  line('BAD id status (expect 400)', `${badId.status} ${badId.body?.error?.code}`);

  const badSearch = await get('/api/cars?source=used&q=bmw');
  check('unsupported used search rejected', badSearch.status === 400);
  line('USED+search status (expect 400)', `${badSearch.status} ${badSearch.body?.error?.code}`);

  const badFilter = await get('/api/cars?bodyType=suv');
  check('unsupported filter rejected', badFilter.status === 400);
  line('UNKNOWN filter status (expect 400)', `${badFilter.status} ${badFilter.body?.error?.code}`);

  const badSource = await get('/api/cars?source=nope');
  check('unknown source rejected', badSource.status === 400);
  line('UNKNOWN source status (expect 400)', `${badSource.status} ${badSource.body?.error?.code}`);

  if (failures.length > 0) {
    process.stderr.write(`SMOKE FAILED: ${failures.join(', ')}\n`);
    process.exitCode = 1;
  } else {
    line('smoke result', 'passed');
  }
} catch (error) {
  const errorName = typeof error?.name === 'string' ? error.name : 'Error';
  const errorCode = typeof error?.cause?.code === 'string' ? error.cause.code : '';
  console.error(`SMOKE FAILED: ${errorName}${errorCode ? ` (${errorCode})` : ''}`);
  process.exitCode = 1;
} finally {
  await new Promise((resolve) => server.close(resolve));
}
