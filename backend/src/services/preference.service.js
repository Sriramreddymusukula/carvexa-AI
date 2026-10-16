import { Preference, User } from '../models/index.js';
import { ApiError } from '../utils/apiError.js';

async function assertUserExists(userId) {
  const exists = await User.exists({ _id: userId });
  if (!exists) throw ApiError.notFound('User not found');
}

export const preferenceService = {
  async getForUser(userId) {
    await assertUserExists(userId);
    const preference = await Preference.findOne({ user: userId }).exec();
    return preference ? preference.toJSON() : null;
  },

  /**
   * Upsert. Uses a document save rather than findOneAndUpdate on purpose:
   * Mongoose does not run document `pre('validate')` hooks on query helpers,
   * and the normalisation + budget cross-check live in that hook.
   */
  async upsertForUser(userId, input) {
    await assertUserExists(userId);

    const existing = await Preference.findOne({ user: userId }).exec();
    const document = existing ? Object.assign(existing, input) : new Preference({ user: userId, ...input });
    const saved = await document.save();

    return { preference: saved.toJSON(), created: !existing };
  },
};

