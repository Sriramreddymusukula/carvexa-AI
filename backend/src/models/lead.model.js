import mongoose from 'mongoose';

const snapshotSchema = new mongoose.Schema(
  {
    title: { type: String, trim: true, maxlength: 160 },
    source: { type: String, enum: ['new', 'used'], required: true },
    year: { type: Number, min: 1900, max: 2100 },
    price: { type: Number, min: 0 },
    formattedPrice: { type: String, trim: true, maxlength: 100 },
    imageUrl: { type: String, trim: true, maxlength: 500 },
    make: { type: String, trim: true, maxlength: 60 },
    model: { type: String, trim: true, maxlength: 80 },
    location: { type: String, trim: true, maxlength: 120 },
  },
  { _id: false },
);

const leadSchema = new mongoose.Schema(
  {
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true, index: true },
    externalCarId: { type: String, required: true, trim: true, maxlength: 512 },
    snapshot: { type: snapshotSchema, required: true },
    note: { type: String, trim: true, maxlength: 500 },
    contactConsent: {
      type: Boolean,
      required: true,
      validate: {
        validator: (value) => value === true,
        message: 'Contact consent must be affirmative',
      },
    },
    contactConsentAt: { type: Date, required: true, default: Date.now },
    contact: {
      fullName: { type: String, required: true, trim: true, maxlength: 100 },
      email: { type: String, required: true, trim: true, lowercase: true, maxlength: 254 },
      phone: { type: String, trim: true, maxlength: 30 },
      city: { type: String, trim: true, maxlength: 80 },
      countryCode: { type: String, trim: true, uppercase: true, minlength: 2, maxlength: 2 },
      _id: false,
    },
    emailNotification: {
      status: {
        type: String,
        enum: ['pending', 'not_configured', 'accepted', 'failed'],
        default: 'pending',
      },
      attemptedAt: { type: Date },
      providerMessageId: { type: String, trim: true, maxlength: 200 },
      _id: false,
    },
  },
  {
    timestamps: true,
    collection: 'leads',
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

leadSchema.index({ user: 1, externalCarId: 1 }, { unique: true, name: 'uniq_user_car_interest' });
leadSchema.index({ createdAt: -1 }, { name: 'idx_lead_createdAt' });

export const Lead = mongoose.models.Lead || mongoose.model('Lead', leadSchema);
