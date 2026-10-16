import { getDatabaseHealth } from '../services/health.service.js';

/**
 * GET /api/health
 *
 * 200 only when the API and the database are both usable; 503 otherwise, so a
 * monitoring system or the Flutter client cannot mistake "server up, data down"
 * for a healthy backend.
 */
export async function healthHandler(req, res) {
  const database = await getDatabaseHealth();
  const healthy = database.status === 'connected';

  res.status(healthy ? 200 : 503).json({
    status: healthy ? 'ok' : 'degraded',
    service: 'flutter-car-backend',
    database,
  });
}
