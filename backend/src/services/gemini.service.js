import { env } from '../config/env.js';
import { ApiError } from '../utils/apiError.js';
import { logger } from '../utils/logger.js';

const SYSTEM_INSTRUCTION = `You are Carvexa AI, a calm and knowledgeable automotive buying assistant.
Use the supplied catalog records as the only source for specific vehicle facts. Do not guess missing prices, years, features, safety ratings, seller details, or specifications. Say when catalog data is unavailable. Clearly distinguish catalog facts from general automotive guidance.
Answer the user's message directly, in plain prose, and keep it under about 300 words.`;

const RETRY_INSTRUCTION =
  '\n\nAnswer the previous user message directly and in full. Reply with normal prose about the vehicles above, not with a status or a one-word message.';

/** Degenerate free-tier output that answers nothing (observed live). */
const DEGENERATE_PATTERNS = [
  /^user\s*safety\s*:/i,
  /^content\s*policy/i,
  /^(safe|n\/a|na|test)[.!]?$/i,
];

/**
 * True when the model produced a real answer. Detects degenerate replies
 * (e.g. `User Safety: safe`) so the caller can retry instead of shipping
 * garbage to the app.
 */
export function isUsableAnswer(text) {
  if (typeof text !== 'string') return false;
  const trimmed = text.trim();
  if (trimmed.length < 3) return false;
  return !DEGENERATE_PATTERNS.some((pattern) => pattern.test(trimmed));
}

/**
 * Our wire roles (`user` | `model`) -> OpenAI-style `user` | `assistant`.
 *
 * Sending `role: "model"` to an OpenAI-compatible gateway is a 400 error -
 * this mapping is what makes every real conversation work.
 */
export function toOpenAiMessages(messages) {
  return messages.map(({ role, text }) => ({
    role: role === 'model' || role === 'assistant' ? 'assistant' : 'user',
    content: text,
  }));
}

/** Our turns -> Gemini contents (`role: user` | `model` plus parts). */
export function toGeminiContents(messages) {
  return messages.map(({ role, text }) => ({
    role: role === 'model' || role === 'assistant' ? 'model' : 'user',
    parts: [{ text }],
  }));
}

async function readJson(response) {
  const text = await response.text();
  if (text.length === 0) return null;
  try {
    return JSON.parse(text);
  } catch {
    return null;
  }
}

/** Maps an upstream status onto one clear, user-safe failure. */
function failureFrom(status, service) {
  if (status === 401 || status === 403) {
    return ApiError.serviceUnavailable('Carvexa AI is not configured correctly on the server.');
  }
  if (status === 429) {
    return ApiError.serviceUnavailable(
      'Carvexa AI is receiving too many requests right now. Try again shortly.',
    );
  }
  if (status === 402) {
    return ApiError.serviceUnavailable('The AI service is out of credit. Try again later.');
  }
  logger.warn(`${service} returned a non-success status`, { status });
  return ApiError.serviceUnavailable('Carvexa AI is temporarily unavailable. Try again shortly.');
}

function toApiError(error) {
  if (error instanceof ApiError) return error;
  const name = typeof error?.name === 'string' ? error.name : 'Error';
  if (name === 'TimeoutError' || name === 'AbortError') {
    return ApiError.serviceUnavailable('Carvexa AI took too long to respond. Try again.');
  }
  logger.warn('AI transport error', { reason: name, causeCode: error?.cause?.code ?? null });
  return ApiError.serviceUnavailable('Could not reach the AI service. Try again shortly.');
}

/** OpenAI-compatible chat completion (OpenRouter). */
async function callOpenRouter({ systemText, messages, timeoutMs }) {
  const response = await fetch(`${env.openRouterBaseUrl}/chat/completions`, {
    method: 'POST',
    headers: {
      authorization: `Bearer ${env.openRouterApiKey}`,
      'content-type': 'application/json',
    },
    body: JSON.stringify({
      model: env.openRouterModel,
      messages: [
        { role: 'system', content: systemText },
        ...toOpenAiMessages(messages),
      ],
      temperature: 0.35,
      max_tokens: 1000,
    }),
    signal: AbortSignal.timeout(timeoutMs),
  });

  const payload = await readJson(response);
  if (!response.ok) throw failureFrom(response.status, 'OpenRouter');

  const raw = payload?.choices?.[0]?.message?.content;
  const content = Array.isArray(raw)
    ? raw.map((part) => (typeof part?.text === 'string' ? part.text : '')).join('')
    : typeof raw === 'string'
      ? raw
      : '';

  if (content.trim().length === 0) {
    throw ApiError.serviceUnavailable('Carvexa AI returned an empty answer. Try again.');
  }
  return content.trim();
}

/** Google Gemini generateContent. */
async function callGemini({ systemText, messages, timeoutMs }) {
  const model = encodeURIComponent(env.geminiModel);
  const response = await fetch(
    `https://generativelanguage.googleapis.com/v1beta/models/${model}:generateContent`,
    {
      method: 'POST',
      headers: {
        'x-goog-api-key': env.geminiApiKey,
        'content-type': 'application/json',
      },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: systemText }] },
        contents: toGeminiContents(messages),
        generationConfig: { temperature: 0.35, maxOutputTokens: 1000 },
      }),
      signal: AbortSignal.timeout(timeoutMs),
    },
  );

  const payload = await readJson(response);
  if (!response.ok) throw failureFrom(response.status, 'Gemini');

  const blockReason = payload?.promptFeedback?.blockReason;
  if (blockReason) {
    logger.warn('Gemini blocked the prompt', { blockReason });
    throw ApiError.serviceUnavailable('Carvexa AI declined to answer that request.');
  }

  const parts = payload?.candidates?.[0]?.content?.parts ?? [];
  const content = parts
    .map((part) => (typeof part?.text === 'string' ? part.text : ''))
    .join('')
    .trim();

  if (content.length === 0) {
    throw ApiError.serviceUnavailable('Carvexa AI returned an empty answer. Try again.');
  }
  return content;
}

/** Two attempts: a normal one, then one with a stricter instruction. */
const MAX_ATTEMPTS = 2;

/** Per attempt, so two attempts always fit inside the app's 45s chat budget. */
const ATTEMPT_TIMEOUT_MS = Math.min(env.geminiTimeoutMs, 18000);

/**
 * Generates one grounded answer.
 *
 * Flow: Flutter -> Express (`/api/ai/chat`) -> this function -> the configured
 * AI provider -> validated text back to Flutter.
 *
 * The Gemini key lives only in `backend/.env`; nothing here is ever shipped to
 * the app. When `GEMINI_API_KEY` is set the Google API is used, otherwise the
 * OpenRouter gateway (`OPENROUTER_*`).
 *
 * @param {{
 *   messages: Array<{ role: 'user' | 'model' | 'assistant', text: string }>,
 *   catalogVehicles?: Array<Record<string, unknown>>,
 *   catalogIndex?: Array<Record<string, unknown>> | null,
 *   preferences?: Record<string, unknown> | null,
 * }} request
 * @returns {Promise<string>} a usable answer, or a clear failure.
 */
export async function generateAnswer({
  messages,
  catalogVehicles = [],
  catalogIndex = null,
  preferences = null,
}) {
  const provider = env.aiProvider;
  if (provider === 'none') {
    throw ApiError.serviceUnavailable('Carvexa AI is not configured on the server.');
  }

  const systemParts = [SYSTEM_INSTRUCTION];
  if (catalogVehicles.length > 0) {
    systemParts.push(
      `MATCHED CATALOG VEHICLES (JSON):\n${JSON.stringify(catalogVehicles)}`,
    );
  }
  if (Array.isArray(catalogIndex) && catalogIndex.length > 0) {
    systemParts.push(`AVAILABLE VEHICLE INDEX (JSON):\n${JSON.stringify(catalogIndex)}`);
  }
  if (preferences != null) {
    systemParts.push(`USER BUYING PREFERENCES (JSON):\n${JSON.stringify(preferences)}`);
  }
  const baseSystem = systemParts.join('\n\n');

  let lastError = null;

  for (let attempt = 1; attempt <= MAX_ATTEMPTS; attempt += 1) {
    const systemText = attempt === 1 ? baseSystem : baseSystem + RETRY_INSTRUCTION;

    try {
      const answer =
        provider === 'gemini'
          ? await callGemini({ systemText, messages, timeoutMs: ATTEMPT_TIMEOUT_MS })
          : await callOpenRouter({ systemText, messages, timeoutMs: ATTEMPT_TIMEOUT_MS });

      if (isUsableAnswer(answer)) return answer.slice(0, 6000);

      logger.warn('AI returned an unusable answer', {
        provider,
        attempt,
        length: answer.length,
      });
      lastError = ApiError.serviceUnavailable(
        'Carvexa AI could not produce an answer just now. Try again.',
      );
    } catch (error) {
      lastError = toApiError(error);
      logger.warn('AI attempt failed', {
        provider,
        attempt,
        code: lastError.code,
        message: lastError.message,
      });
    }
  }

  throw lastError ?? ApiError.serviceUnavailable('Carvexa AI is temporarily unavailable. Try again shortly.');
}

export { SYSTEM_INSTRUCTION };
