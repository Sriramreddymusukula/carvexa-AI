import { authService } from '../services/auth.service.js';

export async function register(req, res) {
  res.status(201).json({ data: await authService.register(req.valid.body) });
}

export async function login(req, res) {
  res.json({ data: await authService.login(req.valid.body) });
}

export async function logout(req, res) {
  res.json({ data: await authService.logout(req.auth.userId) });
}
