import dgram from 'node:dgram';

export const DISCOVERY_PORT = 4001;
export const DISCOVERY_REQUEST = 'CARVEXA_DISCOVER_V1';

/**
 * Answers local IPv4 broadcast requests with the API port. The client uses the
 * source address of this reply as the PC's current LAN address.
 */
export function startBackendDiscovery({
  apiPort,
  discoveryPort = DISCOVERY_PORT,
  host = '0.0.0.0',
}) {
  const socket = dgram.createSocket('udp4');
  socket.on('message', (message, remote) => {
    if (message.toString('utf8') !== DISCOVERY_REQUEST) return;
    const response = Buffer.from(JSON.stringify({ service: 'carvexa-api', port: apiPort }));
    socket.send(response, remote.port, remote.address);
  });
  socket.bind(discoveryPort, host);
  return socket;
}
