import { Router } from 'express';

import { env } from '../config/env.js';
import { ownedCollections } from '../models/index.js';
import { apiLimiter } from '../middleware/rateLimiter.js';
import carRoutes from './car.routes.js';
import authRoutes from './auth.routes.js';
import favoriteRoutes from './favorite.routes.js';
import healthRoutes from './health.routes.js';
import preferenceRoutes from './preference.routes.js';
import userRoutes from './user.routes.js';
import leadRoutes from './lead.routes.js';
import aiRoutes from './ai.routes.js';

const router = Router();

router.use(apiLimiter);

router.get('/', (_req, res) => {
  res.json({
    service: 'flutter-car-backend',
    environment: env.nodeEnv,
    endpoints: {
      health: '/api/health',
      cars: '/api/cars',
      users: '/api/users',
      auth: '/api/auth',
      favorites: '/api/favorites',
      interests: '/api/interests',
      leads: '/api/leads',
      ai: '/api/ai',
    },
    collections: ownedCollections,
  });
});

router.use('/health', healthRoutes);
router.use('/cars', carRoutes);
router.use('/auth', authRoutes);
router.use('/users', userRoutes);
router.use('/favorites', favoriteRoutes);
router.use('/interests', preferenceRoutes);
router.use('/leads', leadRoutes);
router.use('/ai', aiRoutes);

export default router;
