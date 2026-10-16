import { Lead, User } from '../models/index.js';
import { getCarDetail } from './carCatalog.service.js';
import { sendLeadNotification } from './emailNotification.service.js';
import { ApiError } from '../utils/apiError.js';
import { logger } from '../utils/logger.js';

function snapshotFor(car) {
  return {
    title: car.title,
    source: car.source,
    ...(car.year == null ? {} : { year: car.year }),
    ...(car.price == null ? {} : { price: car.price }),
    ...(car.formattedPrice == null ? {} : { formattedPrice: car.formattedPrice }),
    ...(car.images?.[0]?.url == null ? {} : { imageUrl: car.images[0].url }),
    ...(car.make == null ? {} : { make: car.make }),
    ...(car.model == null ? {} : { model: car.model }),
    ...(car.city == null ? {} : { location: car.city }),
  };
}

/** Dependencies are injectable so lead/email sequencing can be tested offline. */
export function createLeadService({
  userModel = User,
  leadModel = Lead,
  carDetailLookup = getCarDetail,
  notify = sendLeadNotification,
  log = logger,
} = {}) {
  return {
    async create(userId, { externalCarId, note, contactConsent }) {
      const [user, car] = await Promise.all([
        userModel.findById(userId).exec(),
        carDetailLookup(externalCarId),
      ]);
      if (!user) throw ApiError.unauthorized('Your session has expired. Sign in again.');

      let lead;
      try {
        // The lead is durable before any email-provider request is attempted.
        lead = await leadModel.create({
          user: userId,
          externalCarId,
          snapshot: snapshotFor(car),
          note,
          contactConsent,
          contactConsentAt: new Date(),
          contact: {
            fullName: user.fullName,
            email: user.email,
            ...(user.phone ? { phone: user.phone } : {}),
            ...(user.city ? { city: user.city } : {}),
            ...(user.countryCode ? { countryCode: user.countryCode } : {}),
          },
          emailNotification: { status: 'pending' },
        });
      } catch (error) {
        if (error?.code === 11000) {
          throw ApiError.conflict('You have already expressed interest in this vehicle');
        }
        throw error;
      }

      let notification;
      try {
        notification = await notify(lead);
      } catch (error) {
        notification = { status: 'failed' };
        // Never include the message or provider body; it may contain PII or
        // credentials. The lead itself remains persisted and can be followed up.
        log.warn('Lead notification failed', {
          error: error?.name || 'Error',
          ...(typeof error?.code === 'string' ? { code: error.code } : {}),
        });
      }

      lead.emailNotification = {
        status: notification.status,
        ...(notification.status === 'not_configured' ? {} : { attemptedAt: new Date() }),
        ...(notification.providerMessageId
          ? { providerMessageId: notification.providerMessageId }
          : {}),
      };

      // If the tracking update fails, don't turn a successfully created lead
      // into an apparent failed request that the user might submit twice.
      try {
        await lead.save();
      } catch (error) {
        log.warn('Lead notification status could not be saved', {
          error: error?.name || 'Error',
          ...(typeof error?.code === 'string' ? { code: error.code } : {}),
        });
      }

      return {
        lead: lead.toJSON(),
        emailNotification: {
          status: notification.status,
          ...(notification.providerMessageId
            ? { providerMessageId: notification.providerMessageId }
            : {}),
        },
      };
    },
  };
}

export const leadService = createLeadService();
