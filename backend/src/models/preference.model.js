import mongoose from 'mongoose';

/**
 * One preference document per user: budget, body/fuel/transmission filters,
 * preferred makes and free-text notes. The AI recommendation endpoint uses
 * these values as context, and the document is entirely application-owned.
 *
 * Makes / body types / fuel types are deliberately NOT closed enums: their
 * vocabulary comes from the external catalog API. Hard-coding it would make
 * the filter brittle as provider data changes. Values are normalised (trimmed,
 * lower-cased, deduped)
 * and length-capped instead.
 *
 * @typedef {import('mongoose').Document & {
 *   user: import('mongoose').Types.ObjectId;
 *   budget?: { min?: number; max?: number };
 *   bodyTypes: string[];
 *   fuelTypes: string[];
 *   transmission?: string;
 *   makes: string[];
 *   notes?: string;
 * }} IPreferenceDocument
 */

export const TRANSMISSION_FILTERS = ['any', 'automatic', 'manual'];

const MAX_LIST_ITEMS = 25;

/** Normalise a free-text filter list; rejects values that are not strings. */
function normalizeList(values) {
  return [
    ...new Set(
      (values ?? [])
        .map((value) => String(value).trim().toLowerCase())
        .filter((value) => value.length > 0),
    ),
  ];
}

function listField(label) {
  return {
    type: [
      {
        type: String,
        trim: true,
        lowercase: true,
        maxlength: 60,
      },
    ],
    default: [],
    validate: [
      {
        validator: (values) => values.length <= MAX_LIST_ITEMS,
        message: `${label} accepts at most ${MAX_LIST_ITEMS} values`,
      },
      {
        validator: (values) => values.every((value) => typeof value === 'string' && value.length > 0),
        message: `${label} must contain non-empty strings only`,
      },
    ],
  };
}

const preferenceSchema = new mongoose.Schema(
  {
    user: {
      type: mongoose.Schema.Types.ObjectId,
      ref: 'User',
      required: [true, 'user is required'],
    },
    budget: {
      min: { type: Number, min: [0, 'budget.min must be >= 0'] },
      max: {
        type: Number,
        min: [0, 'budget.max must be >= 0'],
      },
      currency: {
        type: String,
        trim: true,
        uppercase: true,
        minlength: 3,
        maxlength: 3,
        default: 'INR',
      },
      _id: false,
    },
    bodyTypes: listField('bodyTypes'),
    fuelTypes: listField('fuelTypes'),
    transmission: { type: String, enum: TRANSMISSION_FILTERS, default: 'any' },
    makes: listField('makes'),
    notes: { type: String, trim: true, maxlength: 1000 },
  },
  {
    timestamps: true,
    collection: 'preferences',
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

/**
 * Normalise the free-text filter lists and cross-check the budget before
 * validation runs, so every write path (HTTP API, scripts, later background
 * jobs) behaves identically instead of relying on each caller to clean input.
 */
preferenceSchema.pre('validate', async function normalizeBeforeValidation() {
  this.bodyTypes = normalizeList(this.bodyTypes);
  this.fuelTypes = normalizeList(this.fuelTypes);
  this.makes = normalizeList(this.makes);

  const min = this.budget?.min;
  const max = this.budget?.max;
  if (typeof min === 'number' && typeof max === 'number' && max < min) {
    this.invalidate('budget.max', 'budget.max must be greater than or equal to budget.min');
  }
});

// One preference document per user. This named index is reconciled against
// equivalent legacy MongoDB index names during startup.
preferenceSchema.index({ user: 1 }, { unique: true, name: 'uniq_user' });

export const Preference =
  mongoose.models.Preference || mongoose.model('Preference', preferenceSchema);
