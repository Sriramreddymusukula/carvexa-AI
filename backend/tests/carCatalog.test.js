/**
 * Car catalogue unit tests. Fully offline: no provider call is ever made, so
 * the suite costs no credits and never depends on live upstream data.
 *
 * Run with: npm test
 */
import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'error';
// The suite must never reach the network, so the catalogue stays disabled.
process.env.CAR_CATALOG_PROVIDER = 'none';

const { decodeCarId, encodeCarId } = await import('../src/services/carCatalog/idCodec.js');
const { describeCatalog } = await import(
  '../src/services/carCatalog/carDekhoProvider.js'
);
const { listCarsQuery } = await import('../src/validators/car.validator.js');

describe('catalog identifiers', () => {
  it('round-trips a model reference', () => {
    const decoded = decodeCarId(encodeCarId({ kind: 'model', brand: 'tata', model: 'nexon' }));
    assert.deepEqual(decoded, { kind: 'model', brand: 'tata', model: 'nexon' });
  });

  it('round-trips a listing reference', () => {
    const url = 'https://www.cardekho.com/used-car-details/used-Volvo-xc90-cars-Gurgaon_abc.htm';
    const decoded = decodeCarId(encodeCarId({ kind: 'listing', url }));
    assert.deepEqual(decoded, { kind: 'listing', url });
  });

  it('does not leak the upstream URL in a model id', () => {
    const id = encodeCarId({ kind: 'model', brand: 'tata', model: 'nexon' });
    assert.ok(!id.includes('cardekho'), 'a model id must not reference the provider');
  });

  it('rejects a tampered id', () => {
    const id = encodeCarId({ kind: 'model', brand: 'tata', model: 'nexon' });
    const [body] = id.split('.');
    assert.throws(() => decodeCarId(`${body}.aaaaaaaaaaaaaaaaaaaaaa`));
  });

  it('rejects an unsigned or malformed id', () => {
    for (const bad of ['', 'nope', 'aaaa.bbbb', undefined, 'a'.repeat(600)]) {
      assert.throws(() => decodeCarId(bad));
    }
  });

  it('refuses an id that points at a host we do not fetch from', () => {
    // The signature is forged here, so the allowlist check is what must hold the
    // line: a listing id may only ever address an upstream detail page.
    const payload = Buffer.from(
      JSON.stringify({ k: 'u', u: 'https://169.254.169.254/latest/meta-data/' }),
      'utf8',
    ).toString('base64url');
    assert.throws(() => decodeCarId(`${payload}.aaaaaaaaaaaaaaaaaaaaaa`));
  });

  it('rejects slugs that are not provider slugs', () => {
    for (const brand of ['../etc', 'Tata', 'a b', '']) {
      const payload = Buffer.from(JSON.stringify({ k: 'n', b: brand, m: 'nexon' }), 'utf8')
        .toString('base64url');
      assert.throws(() => decodeCarId(`${payload}.aaaaaaaaaaaaaaaaaaaaaa`));
    }
  });
});

describe('catalog capabilities', () => {
  const capabilities = describeCatalog();

  it('advertises exactly the two real sources', () => {
    assert.deepEqual(
      capabilities.sources.map((source) => source.id),
      ['used', 'new'],
    );
  });

  it('marks search as available only where the provider supports it', () => {
    const used = capabilities.sources.find((source) => source.id === 'used');
    const fresh = capabilities.sources.find((source) => source.id === 'new');

    // Used listings are paged and filtered by city, never searched; the new-car
    // model index is fully enumerable, so it is searchable.
    assert.equal(used.search, false);
    assert.equal(used.pagination, true);
    assert.equal(fresh.search, true);
    assert.equal(fresh.pagination, false);
  });

  it('offers only filters the provider can actually apply', () => {
    const used = capabilities.sources.find((source) => source.id === 'used');
    const fresh = capabilities.sources.find((source) => source.id === 'new');

    assert.deepEqual(used.filters, []);
    assert.deepEqual(
      fresh.filters.map((filter) => filter.id),
      ['brand'],
    );
    assert.equal(used.description.includes('Hyderabad'), true);
  });
});

describe('catalog query validation', () => {
  it('accepts the filters the provider supports', () => {
    const result = listCarsQuery.safeParse({
      source: 'new',
      brand: 'tata',
      q: 'nexon ev',
      page: '2',
    });
    assert.equal(result.success, true);
    assert.equal(result.data.page, 2, 'page must be coerced to a number');
  });

  it('only accepts Hyderabad as a used-car city', () => {
    assert.equal(listCarsQuery.safeParse({ source: 'used', city: 'hyderabad' }).success, true);
    assert.equal(listCarsQuery.safeParse({ source: 'used', city: 'new-delhi' }).success, false);
  });

  it('rejects an unknown filter instead of ignoring it', () => {
    // Silently dropping an unsupported filter is how a UI ends up showing a
    // control that does nothing, so it must be a client error.
    assert.equal(listCarsQuery.safeParse({ bodyType: 'suv' }).success, false);
    assert.equal(listCarsQuery.safeParse({ minPrice: 100 }).success, false);
  });

  it('rejects a malformed slug, an unknown source and an out-of-range page', () => {
    assert.equal(listCarsQuery.safeParse({ city: 'New Delhi' }).success, false);
    assert.equal(listCarsQuery.safeParse({ city: '../etc/passwd' }).success, false);
    assert.equal(listCarsQuery.safeParse({ source: 'nope' }).success, false);
    assert.equal(listCarsQuery.safeParse({ page: '0' }).success, false);
    assert.equal(listCarsQuery.safeParse({ page: '0' }).success, false);
  });

  it('caps the search length so a pathological query is never forwarded', () => {
    assert.equal(listCarsQuery.safeParse({ q: 'x'.repeat(200) }).success, false);
  });
});
