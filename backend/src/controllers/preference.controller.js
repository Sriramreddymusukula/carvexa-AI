import { preferenceService } from '../services/preference.service.js';

/** GET /api/interests/:userId — 200 with `data: null` when nothing is set yet. */
export async function getInterests(req, res) {
  const data = await preferenceService.getForUser(req.auth.userId);
  res.json({ data });
}

/** PUT /api/interests/:userId — create-or-replace the preference document. */
export async function upsertInterests(req, res) {
  const { preference, created } = await preferenceService.upsertForUser(
    req.auth.userId,
    req.valid.body,
  );
  res.status(created ? 201 : 200).json({ data: preference });
}
