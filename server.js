import express from 'express';
import session from 'express-session';
import config from './config.js';
import { streamChat, OllamaClientError } from './lib/ollamaClient.js';
import { bufferBySentence } from './lib/sentenceBuffer.js';
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

  // Cancel the upstream Ollama call when the client disconnects (Stop button,
  // tab close, network drop). Without this, Ollama keeps generating after
  // the user hit Stop — wastes CPU and ties up the model for ~20s.
  //
  // Use res.on('close'), NOT req.on('close'). On Node 16+, the request
  // emits 'close' as soon as its body has been fully read — for a small
  // POST that's milliseconds in, well before streaming finishes. The
  // response only emits 'close' if the connection terminates before
  // res.end() was reached, which is exactly the disconnect signal we want.
  const upstream = new AbortController();
  res.on('close', () => {
    if (!res.writableEnded) upstream.abort();
  });

  let assistantBuffer = '';
  try {
    for await (const token of bufferBySentence(
      streamChat(context.get(sessionId), upstream.signal),
    )) {
      assistantBuffer += token;
      if (!res.writableEnded) res.write(`data: ${JSON.stringify({ token })}\n\n`);
    }
    context.append(sessionId, { role: 'assistant', content: assistantBuffer });
    if (!res.writableEnded) res.write(`data: ${JSON.stringify({ done: true })}\n\n`);
  } catch (err) {
    // Client aborted (Stop button): save the partial reply so reload still
    // shows a coherent conversation, and exit quietly — the connection is
    // already gone so we can't write an error event to it.
    if (err.name === 'AbortError' || upstream.signal.aborted) {
      if (assistantBuffer) {
        context.append(sessionId, { role: 'assistant', content: assistantBuffer });
      }
      return;
    }
    // Developer-facing message goes to server logs for diagnostics.
    console.error('[chat]', err.message);
    // User-facing message goes to the client. OllamaClientError builds a
    // phrasing that's safe to render; anything else falls back to a generic
    // line so internal error text never leaks to the UI.
    const userMessage =
      err instanceof OllamaClientError
        ? err.userMessage
        : 'Something went wrong. Please try again.';
    if (!res.writableEnded) res.write(`data: ${JSON.stringify({ error: userMessage })}\n\n`);
  } finally {
    if (!res.writableEnded) res.end();
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
