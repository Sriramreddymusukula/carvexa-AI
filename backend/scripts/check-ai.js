import process from 'node:process';
import 'dotenv/config';
import { generateAnswer } from '../src/services/gemini.service.js';

if (!process.env.OPENROUTER_API_KEY) {
  console.error('OpenRouter is not configured. Set OPENROUTER_API_KEY in backend/.env.');
  process.exitCode = 1;
} else {
  try {
    const answer = await generateAnswer({
      messages: [{ role: 'user', text: 'Reply with READY only.' }],
      catalogVehicles: [],
    });

    console.log(`OpenRouter accepted the request: ${answer}`);
  } catch (error) {
    console.error('OpenRouter smoke test failed:', error.message);
    process.exitCode = 1;
  }
}
