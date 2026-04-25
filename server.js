import express from 'express';
import session from 'express-session';
import config from './config.js';
import { streamChat, OllamaClientError } from './lib/ollamaClient.js';
import * as context from './lib/context.js';

const app = express();

app.use(
  session({
    secret: config.sessionSecret,
    resave: false,
    // saveUninitialized: true so the Set-Cookie reaches the client on the
    // first request even before we've stored anything in req.session — the
    // conversation history lives in our own Map keyed by req.sessionID.
    saveUninitialized: true,
    cookie: { httpOnly: true, sameSite: 'lax' },
  }),
);

app.use(express.json());
app.use(express.static('static'));

app.post('/chat', async (req, res) => {
  const prompt = req.body?.prompt;
  if (typeof prompt !== 'string' || !prompt.trim()) {
    return res.status(400).json({ error: 'prompt must be a non-empty string' });
  }

  const sessionId = req.sessionID;

  if (context.get(sessionId).length === 0) {
    context.append(sessionId, { role: 'system', content: config.systemPrompt });
  }
  context.append(sessionId, { role: 'user', content: prompt });

  res.setHeader('Content-Type', 'text/event-stream');
  res.setHeader('Cache-Control', 'no-cache');
  res.setHeader('Connection', 'keep-alive');
  res.flushHeaders();

  let assistantBuffer = '';
  try {
    for await (const token of streamChat(context.get(sessionId))) {
      assistantBuffer += token;
      res.write(`data: ${JSON.stringify({ token })}\n\n`);
    }
    context.append(sessionId, { role: 'assistant', content: assistantBuffer });
    res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
  } catch (err) {
    const kind = err instanceof OllamaClientError ? err.kind : 'unknown';
    res.write(`data: ${JSON.stringify({ error: kind })}\n\n`);
  } finally {
    res.end();
  }
});

app.post('/new', (req, res) => {
  context.clear(req.sessionID);
  res.status(204).end();
});

app.get('/history', (req, res) => {
  const messages = context.get(req.sessionID).filter((m) => m.role !== 'system');
  res.json({ messages });
});

app.listen(5000, '0.0.0.0', () => console.log('OllamaFile listening on :5000'));
