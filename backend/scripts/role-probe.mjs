// Temporary probe: does role "model" (our wire format) break OpenRouter?
import 'dotenv/config';

const key = process.env.OPENROUTER_API_KEY;
const base = process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1';

const call = async (historyRole) => {
  const response = await fetch(`${base}/chat/completions`, {
    method: 'POST',
    headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
    body: JSON.stringify({
      model: 'openrouter/free',
      messages: [
        { role: 'system', content: 'You are Carvexa AI. Use ONLY the supplied catalog records for vehicle facts.' },
        { role: historyRole, content: 'I am Carvexa AI. Ask about a vehicle.' },
        { role: 'user', content: 'Give me Sorento information' },
      ],
      temperature: 0.35,
      max_tokens: 300,
    }),
    signal: AbortSignal.timeout(25000),
  });
  const payload = await response.json();
  return `${response.status}: ${JSON.stringify(String(payload?.choices?.[0]?.message?.content ?? '').slice(0, 240))}`;
};

console.log('history role "assistant" ->', await call('assistant'));
console.log('history role "model"     ->', await call('model'));
