import { favoriteService } from '../services/favorite.service.js';

export async function createFavorite(req, res) {
  const favorite = await favoriteService.create({ ...req.valid.body, user: req.auth.userId });
  res.status(201).json({ data: favorite });
}

export async function listFavorites(req, res) {
  const { items, total, limit, page } = await favoriteService.listForUser({
    ...req.valid.query,
    user: req.auth.userId,
  });
  res.json({ data: items, meta: { total, limit, page } });
}

export async function deleteFavorite(req, res) {
  res.json({ data: await favoriteService.remove(req.valid.params.id, req.auth.userId) });
}
