import assert from 'node:assert/strict';
import { describe, it } from 'node:test';

import { createLeadService } from '../src/services/lead.service.js';

function fixtures({ notify, car = {} } = {}) {
  const events = [];
  const durable = [];
  const logs = [];
  const userModel = {
    findById(id) {
      return {
        exec: async () =>
          id === 'user-1'
            ? {
                fullName: 'Ada Lovelace',
                email: 'ada@example.com',
                phone: '+447700900123',
                city: 'London',
              }
            : null,
      };
    },
  };
  const leadModel = {
    async create(value) {
      events.push('persist');
      const doc = {
        ...value,
        _id: 'lead-1',
        id: 'lead-1',
        async save() {
          events.push('save-notification-status');
          durable[0] = this.toJSON();
        },
        toJSON() {
          return {
            id: this.id,
            externalCarId: this.externalCarId,
            snapshot: this.snapshot,
            contact: this.contact,
            contactConsent: this.contactConsent,
            emailNotification: this.emailNotification,
          };
        },
      };
      durable.push(doc.toJSON());
      return doc;
    },
  };
  const service = createLeadService({
    userModel,
    leadModel,
    carDetailLookup: async () => car,
    notify: async (lead) => {
      events.push('notify');
      if (notify) return notify(lead, { events, durable });
      return { status: 'not_configured' };
    },
    log: { warn: (message, metadata) => logs.push({ message, metadata }) },
  });

  return { service, events, durable, logs };
}

describe('vehicle interest lead notification', () => {
  const payload = {
    externalCarId: 'real-catalog-id',
    note: 'Please call after 5pm',
    contactConsent: true,
  };

  it('persists the lead before attempting notification and records provider acceptance', async () => {
    const { service, events, durable } = fixtures({
      car: {
        id: 'real-catalog-id',
        title: 'Tata Nexon',
        source: 'new',
        images: [{ url: 'https://images.example/car.jpg' }],
      },
      notify: async (_lead, { events: sequence, durable: records }) => {
        assert.deepEqual(sequence, ['persist', 'notify']);
        assert.equal(records.length, 1);
        return { status: 'accepted', providerMessageId: 'mail-123' };
      },
    });

    const result = await service.create('user-1', payload);

    assert.deepEqual(events, ['persist', 'notify', 'save-notification-status']);
    assert.equal(result.lead.snapshot.title, 'Tata Nexon');
    assert.equal(result.lead.contact.email, 'ada@example.com');
    assert.deepEqual(result.emailNotification, {
      status: 'accepted',
      providerMessageId: 'mail-123',
    });
    assert.equal(durable[0].emailNotification.status, 'accepted');
  });

  it('keeps a created lead when the provider fails and logs no provider message', async () => {
    const { service, durable, logs } = fixtures({
      notify: async () => {
        const error = new Error('contains private provider response');
        error.code = 'HTTP_500';
        throw error;
      },
    });

    const result = await service.create('user-1', payload);

    assert.equal(result.lead.id, 'lead-1');
    assert.equal(result.emailNotification.status, 'failed');
    assert.equal(durable[0].emailNotification.status, 'failed');
    assert.deepEqual(logs, [
      {
        message: 'Lead notification failed',
        metadata: { error: 'Error', code: 'HTTP_500' },
      },
    ]);
  });

  it('reports unconfigured email without claiming an attempt', async () => {
    const { service, durable } = fixtures();

    const result = await service.create('user-1', payload);

    assert.equal(result.emailNotification.status, 'not_configured');
    assert.deepEqual(durable[0].emailNotification, { status: 'not_configured' });
  });

  it('does not create or notify a lead for a missing account', async () => {
    const { service, events } = fixtures();

    await assert.rejects(service.create('missing-user', payload));
    assert.deepEqual(events, []);
  });
});
