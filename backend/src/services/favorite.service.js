import { Favorite, User } from '../models/index.js';
import { ApiError } from '../utils/apiError.js';
import { getFallbackCarById, isLocalCatalogId } from './carCatalog/fallbackCatalog.js';
import { decodeCarId } from './carCatalog/idCodec.js';

async function assertUserExists(userId) {
  const exists = await User.exists({ _id: userId });
  if (!exists) throw ApiError.notFound('User not found');
}

export const favoriteService = {
  async create({ user, externalCarId, source, vehicleType: requestedType, snapshot }) {
    await assertUserExists(user);

    let vehicleType = requestedType;

    if (isLocalCatalogId(externalCarId)) {
      // Locally minted ids (`local-*`, legacy `fallback-*`) are not signed, so
      // the codec cannot decode them. Their catalogue record is the authority:
      // it must exist and agree on the vehicle type.
      const localCar = getFallbackCarById(externalCarId);
      if (localCar === null) throw ApiError.badRequest('That vehicle reference is not valid.');
      if (localCar.source !== requestedType) {
        throw ApiError.badRequest('Vehicle type does not match the catalog item');
      }
      vehicleType = localCar.source;
    } else {
      const decoded = decodeCarId(externalCarId);
      vehicleType = decoded.kind === 'model' ? 'new' : 'used';
      if (requestedType !== vehicleType) {
        throw ApiError.badRequest('Vehicle type does not match the catalog item');
      }
    }

    try {
      const created = await Favorite.create({ user, externalCarId, source, vehicleType, snapshot });
      return created.toJSON();
    } catch (error) {
      // The unique index is the authority; translate it into a clean 409.
      if (error?.code === 11000) {
        throw ApiError.conflict('This car is already saved by the user', [
          { field: 'body.externalCarId', message: 'already saved' },
        ]);
      }
      throw error;
    }
  },

  async listForUser({ user, limit, page }) {
    const filter = { user };
    const [items, total] = await Promise.all([
      Favorite.find(filter)
        .sort({ createdAt: -1 })
        .skip((page - 1) * limit)
        .limit(limit)
        .exec(),
      Favorite.countDocuments(filter),
    ]);

    return { items: items.map((item) => item.toJSON()), total, limit, page };
  },

  /** @returns {Promise<{ deleted: boolean }>} */
  async remove(id, user) {
    const deleted = await Favorite.findOneAndDelete({ _id: id, user }).exec();
    if (!deleted) throw ApiError.notFound('Favorite not found');
    return { deleted: true };
  },
};
