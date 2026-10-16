import assert from 'node:assert/strict';
import { after, describe, it } from 'node:test';

process.env.NODE_ENV = 'test';
process.env.LOG_LEVEL = 'error';
process.env.EMAIL_PROVIDER = 'resend';
process.env.RESEND_API_KEY = 'test-resend-key-not-a-real-secret';
process.env.EMAIL_FROM = 'Carvexa Tests <tests@example.invalid>';
process.env.LEAD_NOTIFICATION_EMAIL = 'sriramreddymusukula@gmail.com';
process.env.CAR_CATALOG_PROVIDER = 'none';

const { sendLeadNotification } = await import('../src/services/emailNotification.service.js');

const originalFetch = globalThis.fetch;
after(() => {
  globalThis.fetch = originalFetch;
});

const lead = {
  id: 'lead-1',
  externalCarId: 'catalog-reference',
  snapshot: { title: 'Tata Nexon', source: 'new' },
  contact: {
    fullName: 'Ada Lovelace',
    email: 'ada@example.com',
    phone: '+447700900123',
  },
  note: 'Call after 5pm',
};

describe('Resend lead notification', () => {
  it('posts lead details server-side to the configured recipient', async () => {
    let sent;
    globalThis.fetch = async (url, init) => {
      sent = { url, init, body: JSON.parse(init.body) };
      return new Response(JSON.stringify({ id: 'resend-message-1' }), { status: 200 });
    };

    const result = await sendLeadNotification(lead);

    assert.equal(sent.url, 'https://api.resend.com/emails');
    assert.equal(sent.init.headers.Authorization, 'Bearer test-resend-key-not-a-real-secret');
    assert.equal(sent.body.from, 'Carvexa Tests <tests@example.invalid>');
    assert.deepEqual(sent.body.to, ['sriramreddymusukula@gmail.com']);
    assert.equal(sent.body.reply_to, 'ada@example.com');
    assert.match(sent.body.text, /Tata Nexon/);
    assert.match(sent.body.text, /Call after 5pm/);
    assert.deepEqual(result, { status: 'accepted', providerMessageId: 'resend-message-1' });
  });

  it('does not expose provider response content on failure', async () => {
    globalThis.fetch = async () =>
      new Response('private provider payload', { status: 500 });

    await assert.rejects(sendLeadNotification(lead), (error) => {
      assert.equal(error.code, 'HTTP_500');
      assert.ok(!error.message.includes('private provider payload'));
      return true;
    });
  });
});
