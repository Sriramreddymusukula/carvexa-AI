import { authService } from '../services/auth.service.js';

/** Express 5 forwards rejected promises to the central error handler. */
export async function getUser(req, res) {
  res.json({ data: await authService.getProfile(req.auth.userId) });
}

export async function updateUser(req, res) {
  res.json({ data: await authService.updateProfile(req.auth.userId, req.valid.body) });
}
