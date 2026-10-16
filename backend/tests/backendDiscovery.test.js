import assert from 'node:assert/strict';
import dgram from 'node:dgram';
import { once } from 'node:events';
import test from 'node:test';

import {
  DISCOVERY_REQUEST,
  startBackendDiscovery,
} from '../src/services/backendDiscovery.js';

test('replies to a Carvexa LAN discovery request with the API port', async () => {
  const discovery = startBackendDiscovery({
    apiPort: 4567,
    discoveryPort: 0,
    host: '127.0.0.1',
  });
  const client = dgram.createSocket('udp4');

  try {
    await once(discovery, 'listening');
    const response = once(client, 'message');
    client.send(
      Buffer.from(DISCOVERY_REQUEST),
      discovery.address().port,
      '127.0.0.1',
    );

    const [packet] = await response;
    assert.deepEqual(JSON.parse(packet.toString('utf8')), {
      service: 'carvexa-api',
      port: 4567,
    });
  } finally {
    client.close();
    discovery.close();
  }
});
