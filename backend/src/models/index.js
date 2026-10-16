/**
 * Application-owned collections only. The car catalog and car images come from
 * external providers and are intentionally not modelled here.
 */
export { User, USER_LEAD_SOURCES, USER_STATUSES } from './user.model.js';
export { Favorite, FAVORITE_SOURCES } from './favorite.model.js';
export { Preference, TRANSMISSION_FILTERS } from './preference.model.js';
export { Lead } from './lead.model.js';

import { Favorite } from './favorite.model.js';
import { Preference } from './preference.model.js';
import { User } from './user.model.js';
import { Lead } from './lead.model.js';

export const models = { User, Favorite, Preference, Lead };

/** Names of the collections this backend owns, for startup/health reporting. */
export const ownedCollections = ['users', 'favorites', 'preferences', 'leads'];
