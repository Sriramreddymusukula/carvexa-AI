import { z } from 'zod';

const email = z.string().trim().toLowerCase().email().max(254);
const password = z.string().min(10, 'Password must be at least 10 characters').max(128);

export const registerSchema = z
  .object({
    fullName: z.string().trim().min(2).max(100),
    email,
    password,
    phone: z.string().trim().max(30).optional().or(z.literal('')),
    city: z.string().trim().max(80).optional().or(z.literal('')),
    countryCode: z.string().trim().length(2).transform((value) => value.toUpperCase()).optional(),
  })
  .strict();

export const loginSchema = z.object({ email, password }).strict();

export const profileUpdateSchema = z
  .object({
    fullName: z.string().trim().min(2).max(100).optional(),
    email: email.optional(),
    phone: z.string().trim().max(30).optional().or(z.literal('')),
    city: z.string().trim().max(80).optional().or(z.literal('')),
    countryCode: z.string().trim().length(2).transform((value) => value.toUpperCase()).optional().or(z.literal('')),
  })
  .strict()
  .refine((value) => Object.keys(value).length > 0, 'Provide at least one profile field');
