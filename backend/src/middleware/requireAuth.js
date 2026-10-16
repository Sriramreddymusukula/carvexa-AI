import { User } from '../models/index.js';
import { ApiError } from '../utils/apiError.js';
import { verifyAccessToken } from '../services/auth.service.js';

/** Verifies the signed session and its database-backed revocation version. */
export async function requireAuth(req, _res, next) {
  const match = /^Bearer\s+(.+)$/i.exec(req.get('authorization') ?? '');
  const claims = match ? verifyAccessToken(match[1]) : null;
  if (!claims || !/^[a-f0-9]{24}$/i.test(claims.userId)) return next(ApiError.unauthorized());

  try {
    const user = await User.findById(claims.userId).select('+tokenVersion').exec();
    if (!user || (user.tokenVersion ?? 0) !== claims.tokenVersion) {
      return next(ApiError.unauthorized('Your session has expired. Sign in again.'));
    }
    req.auth = { userId: String(user._id) };
    return next();
  } catch (error) {
    return next(error);
  }
}
