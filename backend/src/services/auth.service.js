import { promisify } from 'node:util';
import { randomBytes, scrypt as scryptCallback, timingSafeEqual, createHmac } from 'node:crypto';

import { env } from '../config/env.js';
import { User } from '../models/index.js';
import { ApiError } from '../utils/apiError.js';

const scrypt = promisify(scryptCallback);
const TOKEN_TTL_SECONDS = 60 * 60 * 24 * 30;

async function hashPassword(password) {
  const salt = randomBytes(16);
  const derived = await scrypt(password, salt, 64);
  return `scrypt$${salt.toString('base64url')}$${Buffer.from(derived).toString('base64url')}`;
}

async function verifyPassword(password, stored) {
  const [, saltText, digestText] = String(stored ?? '').split('$');
  if (!saltText || !digestText) return false;
  try {
    const salt = Buffer.from(saltText, 'base64url');
    const expected = Buffer.from(digestText, 'base64url');
    const actual = Buffer.from(await scrypt(password, salt, expected.length));
    return actual.length === expected.length && timingSafeEqual(actual, expected);
  } catch {
    return false;
  }
}

function signToken(user) {
  const header = Buffer.from(JSON.stringify({ alg: 'HS256', typ: 'JWT' })).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(
    JSON.stringify({ sub: String(user._id), ver: user.tokenVersion ?? 0, iat: now, exp: now + TOKEN_TTL_SECONDS }),
  ).toString('base64url');
  const body = `${header}.${payload}`;
  const signature = createHmac('sha256', env.authTokenSecret).update(body).digest('base64url');
  return `${body}.${signature}`;
}

export function verifyAccessToken(token) {
  if (typeof token !== 'string' || token.length > 2048 || !env.authTokenSecret) return null;
  const parts = token.split('.');
  if (parts.length !== 3) return null;
  const body = `${parts[0]}.${parts[1]}`;
  const expected = createHmac('sha256', env.authTokenSecret).update(body).digest();
  let actual;
  try {
    actual = Buffer.from(parts[2], 'base64url');
  } catch {
    return null;
  }
  if (actual.length !== expected.length || !timingSafeEqual(actual, expected)) return null;
  try {
    const header = JSON.parse(Buffer.from(parts[0], 'base64url').toString('utf8'));
    const payload = JSON.parse(Buffer.from(parts[1], 'base64url').toString('utf8'));
    if (header.alg !== 'HS256' || typeof payload.sub !== 'string' || !Number.isInteger(payload.exp)) return null;
    if (payload.exp <= Math.floor(Date.now() / 1000)) return null;
    return { userId: payload.sub, tokenVersion: Number.isInteger(payload.ver) ? payload.ver : 0 };
  } catch {
    return null;
  }
}

export const authService = {
  async register(input) {
    if (await User.exists({ email: input.email })) {
      throw ApiError.conflict('An account with this email already exists');
    }
    const user = await User.create({
      fullName: input.fullName,
      email: input.email,
      passwordHash: await hashPassword(input.password),
      phone: input.phone || undefined,
      city: input.city || undefined,
      countryCode: input.countryCode,
      leadSource: 'app',
      status: 'active',
    });
    return { token: signToken(user), user: user.toJSON() };
  },

  async login({ email, password }) {
    const user = await User.findOne({ email }).select('+passwordHash +tokenVersion').exec();
    if (!user || !(await verifyPassword(password, user.passwordHash))) {
      throw ApiError.unauthorized('Email or password is incorrect');
    }
    return { token: signToken(user), user: user.toJSON() };
  },

  async getProfile(userId) {
    const user = await User.findById(userId).exec();
    if (!user) throw ApiError.unauthorized('Your session has expired. Sign in again.');
    return user.toJSON();
  },

  async updateProfile(userId, input) {
    const user = await User.findById(userId).exec();
    if (!user) throw ApiError.unauthorized('Your session has expired. Sign in again.');
    for (const [field, value] of Object.entries(input)) {
      user.set(field, value === '' ? undefined : value);
    }
    await user.save();
    return user.toJSON();
  },

  async logout(userId) {
    const result = await User.updateOne({ _id: userId }, { $inc: { tokenVersion: 1 } }).exec();
    if (result.matchedCount === 0) throw ApiError.unauthorized('Your session has expired. Sign in again.');
    return { loggedOut: true };
  },
};

export { hashPassword, verifyPassword };
