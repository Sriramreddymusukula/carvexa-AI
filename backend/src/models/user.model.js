import mongoose from 'mongoose';

/**
 * Application account. Passwords are stored only as scrypt hashes and are
 * omitted from every serialized response.
 *
 * @typedef {import('mongoose').Document & {
 *   fullName: string;
 *   email: string;
 *   phone?: string;
 *   city?: string;
 *   countryCode?: string;
 *   leadSource: string;
 *   status: string;
 *   contactConsent: boolean;
 * }} IUserDocument
 */

const EMAIL_PATTERN = /^[^\s@]+@[^\s@]+\.[^\s@]{2,}$/;
// Loose on purpose: accepts E.164 and common local formats, rejects junk.
const PHONE_PATTERN = /^\+?[0-9 ()-]{7,20}$/;

export const USER_LEAD_SOURCES = ['app', 'web', 'referral', 'walk_in', 'other'];
export const USER_STATUSES = ['new', 'contacted', 'active', 'closed'];

const userSchema = new mongoose.Schema(
  {
    fullName: {
      type: String,
      required: [true, 'fullName is required'],
      trim: true,
      minlength: [2, 'fullName must be at least 2 characters'],
      maxlength: [100, 'fullName must be at most 100 characters'],
    },
    email: {
      type: String,
      required: [true, 'email is required'],
      trim: true,
      lowercase: true,
      match: [EMAIL_PATTERN, 'email is not a valid address'],
      maxlength: 254,
    },
    passwordHash: { type: String, select: false },
    tokenVersion: { type: Number, default: 0, min: 0, select: false },
    phone: {
      type: String,
      trim: true,
      match: [PHONE_PATTERN, 'phone must contain 7-20 digits, optionally starting with +'],
    },
    city: { type: String, trim: true, maxlength: 80 },
    countryCode: {
      type: String,
      trim: true,
      uppercase: true,
      minlength: 2,
      maxlength: 2,
      match: [/^[A-Z]{2}$/, 'countryCode must be an ISO 3166-1 alpha-2 code'],
    },
    leadSource: { type: String, enum: USER_LEAD_SOURCES, default: 'app' },
    status: { type: String, enum: USER_STATUSES, default: 'new' },
    contactConsent: { type: Boolean, default: false },
  },
  {
    timestamps: true,
    collection: 'users',
    toJSON: {
      virtuals: true,
      versionKey: false,
      transform(_doc, ret) {
        delete ret._id;
        delete ret.passwordHash;
        return ret;
      },
    },
  },
);

// Named explicitly so existing installations with MongoDB's default name
// `email_1` can be recognized safely as the same unique email constraint.
userSchema.index({ email: 1 }, { unique: true, name: 'uniq_email' });
// Optional field: partial filter keeps documents without a phone out of the
// unique index instead of treating "missing" as a duplicate value.
userSchema.index(
  { phone: 1 },
  { unique: true, name: 'uniq_phone', partialFilterExpression: { phone: { $type: 'string' } } },
);
// Supports "newest leads first" listing.
userSchema.index({ status: 1, createdAt: -1 }, { name: 'idx_status_createdAt' });

export const User = mongoose.models.User || mongoose.model('User', userSchema);
