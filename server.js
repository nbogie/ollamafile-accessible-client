import express from 'express';
import session from 'express-session';
import config from './config.js';

// TODO: wire up an OllamaClient here that streams POST /api/chat requests
// to config.ollamaHost using Node's global fetch.

const app = express();

app.use(
  session({
    secret: config.sessionSecret,
    resave: false,
    saveUninitialized: false,
    cookie: { httpOnly: true, sameSite: 'lax' },
  }),
);

app.use(express.json());
app.use(express.static('static'));

app.post('/chat', (req, res) => {
  res.status(501).json({ todo: 'chat' });
});

app.post('/new', (req, res) => {
  res.status(501).json({ todo: 'new' });
});

app.get('/history', (req, res) => {
  res.status(501).json({ todo: 'history' });
});

app.listen(5000, '0.0.0.0', () => console.log('OllamaFile listening on :5000'));
