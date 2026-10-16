import { env } from '../config/env.js';
import { aiService } from '../services/ai.service.js';

export function aiCapabilities(_req, res) {
  res.json({ data: { available: env.isGeminiConfigured, assistant: 'Carvexa AI' } });
}

export async function chat(req, res) {
  res.json({ data: await aiService.chat(req.auth.userId, req.valid.body) });
}

export async function recommendations(req, res) {
  res.json({ data: await aiService.recommendations(req.auth.userId) });
}
