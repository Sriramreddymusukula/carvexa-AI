import mongoose from 'mongoose';

/**
 * A car a user has saved.
 *
 * The car catalog itself lives in the external car API and is NOT mirrored
 * here. Only the reference (`externalCarId`) plus a small display `snapshot`
 * are stored, so a favourites list can render without re-quoting the provider.
 * `snapshot` is a display cache, not a source of truth.
 *
 * @typedef {import('mongoose').Document & {
 *   user: import('mongoose').Types.ObjectId;
 *   externalCarId: string;
 *   source: string;
 *   snapshot?: Record<string, unknown>;
 * }} IFavoriteDocument
 */

const MAX_SNAPSHOT_KEYS = 16;

export const FAVORITE_SOURCES = ['external_catalog', 'manual', 'other'];

const snapshotShape = {
  title: { type: String, trim: true, maxlength: 160 },
  year: { type: Number, min: 1900, max: 2100 },
  make: { type: String, trim: true, maxlength: 60 },
  model: { type: String, trim: true, maxlength: 80 },
  trim: { type: String, trim: true, maxlength: 80 },
  owner: { type: String, trim: true, maxlength: 80 },
  price: { type: Number, min: 0 },
  currency: { type: String, trim: true, uppercase: true, minlength: 3, maxlength: 3 },
  bodyType: { type: String, trim: true, maxlength: 40 },
  fuelType: { type: String, trim: true, maxlength: 40 },
  transmission: { type: String, trim: true, maxlength: 40 },
  imageUrl: { type: String, trim: true, maxlength: 500 },
  formattedPrice: { type: String, trim: true, maxlength: 100 },
  mileage: { type: Number, min: 0 },
  location: { type: String, trim: true, maxlength: 120 },
};

/**
 * Caps the snapshot so it can never quietly become a copy of the whole
 * external catalog. Mongoose's strict mode already drops unknown paths; this
 * validator is the explicit backstop (and rejects a present-but-empty
 * snapshot, which strict mode would otherwise accept as `{}`).
 */
const ALLOWED_SNAPSHOT_KEYS = Object.keys(snapshotShape);

function isAllowedSnapshot(snapshot) {
  if (!snapshot || typeof snapshot !== 'object') return false;

  // Mongoose hands this validator a SingleNested subdocument, so unwrap it
  // before inspecting keys — otherwise $__/_doc internals leak in.
  const plain =
    typeof snapshot.toObject === 'function' ? snapshot.toObject({ depopulate: true }) : snapshot;

  const keys = Object.keys(plain).filter((key) => plain[key] !== undefined);
  if (keys.length === 0) return false;
  if (keys.length > MAX_SNAPSHOT_KEYS) return false;
  return keys.every((key) => ALLOWED_SNAPSHOT_KEYS.includes(key));
}


const favoriteSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'user is required'],
      index: true,
    },
    externalCarId: {
      type: String,
      required: [true, 'externalCarId is required'],
      trim: true,
      minlength: 1,
      maxlength: 512,
    },
    source: { type: String, enum: FAVORITE_SOURCES, default: 'external_catalog' },
    vehicleType: { type: String, enum: ['new', 'used'], required: true },
    snapshot: {
      type: new mongoose.Schema(snapshotShape, { _id: false }),
      default: undefined,
      validate: {
        validator: isAllowedSnapshot,
        message: `snapshot may only contain: ${ALLOWED_SNAPSHOT_KEYS.join(', ')}`,
      },
    },
  },
  {
    timestamps: true,
    collection: 'favorites',
    toJSON: {
      virtuals: true,
      versionKey: false,
      transform(_doc, ret) {
        delete ret._id;
        return ret;
      },
    },
  },
);

// A car is saved at most once per user.
favoriteSchema.index(
  { user: 1, externalCarId: 1 },
  { unique: true, name: 'uniq_user_externalCarId' },
);
// Supports "show my favourites, newest first".
favoriteSchema.index({ user: 1, createdAt: -1 }, { name: 'idx_user_createdAt' });

export const Favorite =
  mongoose.models.Favorite || mongoose.model('Favorite', favoriteSchema);
