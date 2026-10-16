import { env } from '../config/env.js';

const EMAIL_TIMEOUT_MS = 10000;

/** Send a lead notification through the configured server-side email provider. */
export async function sendLeadNotification(lead) {
  if (!env.isLeadEmailConfigured) return { status: 'not_configured' };

  const vehicle = String(lead.snapshot?.title || 'Vehicle').replace(/[\r\n]+/g, ' ').slice(0, 120);
  const lines = [
    'A customer submitted a vehicle interest request.',
    '',
    `Vehicle: ${lead.snapshot?.title || 'Unknown vehicle'}`,
    `Source: ${lead.snapshot?.source || 'Unknown'}`,
    `Catalog ID: ${lead.externalCarId}`,
    '',
    `Name: ${lead.contact.fullName}`,
    `Email: ${lead.contact.email}`,
    ...(lead.contact.phone ? [`Phone: ${lead.contact.phone}`] : []),
    ...(lead.contact.city ? [`City: ${lead.contact.city}`] : []),
    ...(lead.note ? ['', `Message: ${lead.note}`] : []),
    '',
    `Lead ID: ${String(lead.id || lead._id)}`,
  ];

  const response = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${env.resendApiKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from: env.emailFrom,
      to: [env.leadNotificationEmail],
      reply_to: lead.contact.email,
      subject: `New Carvexa vehicle interest: ${vehicle}`,
      text: lines.join('\n'),
    }),
    signal: AbortSignal.timeout(EMAIL_TIMEOUT_MS),
  });

  if (!response.ok) {
    // Provider response bodies are intentionally not logged or returned; they
    // can contain recipient details or echoed credentials.
    const error = new Error(`Email provider returned HTTP ${response.status}`);
    error.code = `HTTP_${response.status}`;
    throw error;
  }

  const result = await response.json().catch(() => ({}));
  return {
    status: 'accepted',
    ...(typeof result?.id === 'string' ? { providerMessageId: result.id } : {}),
  };
}
