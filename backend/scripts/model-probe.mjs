// Temporary model probe. Run: node scripts/model-probe.mjs
import process from 'node:process';
import 'dotenv/config';

const key = process.env.OPENROUTER_API_KEY;
const base = process.env.OPENROUTER_BASE_URL || 'https://openrouter.ai/api/v1';

const models = [
  process.env.OPENROUTER_MODEL || 'openrouter/free',
  'deepseek/deepseek-chat-v3-0324:free',
  'google/gemma-3-27b-it:free',
  'meta-llama/llama-3.3-70b-instruct:free',
  'qwen/qwen3-30b-a3b:free',
  'mistralai/mistral-small-3.1-24b-instruct:free',
  'openai/gpt-oss-20b:free',
];

const system = 'You are Carvexa AI. Use ONLY the supplied catalog records for vehicle facts.';
const catalog =
  'CATALOG: [{"title":"Kia Sorento","priceRange":"₹32.00 - 42.00 Lakh","bodyType":"SUV","fuelTypes":["Petrol","Diesel"],"seatingCapacity":7},{"title":"Mahindra XUV700","priceRange":"₹14.49 - 27.99 Lakh","bodyType":"SUV","fuelTypes":["Petrol","Diesel"],"seatingCapacity":7}]';

for (const model of models) {
  const started = Date.now();
  try {
    const response = await fetch(`${base}/chat/completions`, {
      method: 'POST',
      headers: { authorization: `Bearer ${key}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: `${system}\n${catalog}` },
          { role: 'assistant', content: 'I am Carvexa AI. Ask about a vehicle.' },
          { role: 'user', content: 'Give me Sorento information' },
        ],
        temperature: 0.35,
        max_tokens: 400,
      }),
      signal: AbortSignal.timeout(25000),
    });
    const payload = await response.json();
    const text = payload?.choices?.[0]?.message?.content ?? '';
    console.log(
      `--- ${model} [${response.status}] ${Date.now() - started}ms`,
      JSON.stringify(String(text).slice(0, 320)),
    );
    if (!response.ok) console.log('    error:', JSON.stringify(payload).slice(0, 300));
  } catch (error) {
    console.log(`--- ${model} FAILED`, error?.name, error?.message?.slice(0, 120));
  }
}
