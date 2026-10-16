// Temporary end-to-end probe: auth -> AI chat -> recommendations.
// Run: node scripts/e2e-ai-probe.mjs
const base = process.env.PROBE_BASE ?? 'http://localhost:4000/api';

const call = async (path, { method = 'GET', body, token } = {}) => {
  const response = await fetch(`${base}${path}`, {
    method,
    headers: {
      'content-type': 'application/json',
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  let payload = null;
  try {
    payload = await response.json();
  } catch {
    payload = null;
  }
  return { status: response.status, payload };
};

const email = `probe+${Date.now()}@example.com`;
const register = await call('/auth/register', {
  method: 'POST',
  body: { fullName: 'Probe User', email, password: 'probe-password-123' },
});
console.log('register:', register.status, JSON.stringify(register.payload?.data?.user ?? register.payload));
const token = register.payload?.data?.token;
if (!token) {
  console.error('no token');
  process.exit(1);
}

const interests = await call('/interests', {
  method: 'PUT',
  token,
  body: { makes: ['Kia', 'Mahindra'], bodyTypes: ['SUV'], budget: { max: 3000000 } },
});
console.log('interests:', interests.status, JSON.stringify(interests.payload));

for (const question of [
  'Give me Sorento information',
  'Compare Sorento and XUV700',
  'Best SUV under 30 lakh',
]) {
  const started = Date.now();
  const chat = await call('/ai/chat', {
    method: 'POST',
    token,
    body: { messages: [{ role: 'user', text: question }], vehicleIds: [] },
  });
  console.log(`chat "${question}":`, chat.status, `${Date.now() - started}ms`);
  console.log('  reply:', JSON.stringify(chat.payload?.data?.reply ?? chat.payload));
  console.log('  grounded:', JSON.stringify(chat.payload?.data?.groundedVehicles ?? null));
}

const rec = await call('/ai/recommendations', { method: 'POST', token, body: {} });
console.log('recommendations:', rec.status);
console.log('  explanation:', JSON.stringify(rec.payload?.data?.explanation ?? rec.payload));
console.log('  vehicles:', (rec.payload?.data?.vehicles ?? []).map((v) => v.title).join(' | '));
