// Central configuration for OllamaFile.
// All values are overridable via environment variables so the same image can
// run in dev, CI, and production without code changes.

const DEFAULT_SYSTEM_PROMPT = `You are a helpful assistant. Always respond in plain prose — no markdown, no bullet symbols, no asterisks, no hash signs, no numbered lists. Write in clear paragraphs, as if writing a letter. Be concise unless the user asks for detail.`;

const config = {
  ollamaHost: process.env.OLLAMA_HOST || 'http://ollama:11434',
  ollamaModel: process.env.OLLAMA_MODEL || 'llama3.2:1b',
  // WARNING: the default session secret is insecure and intended for local dev
  // only. Always override SESSION_SECRET in production with a long random value.
  sessionSecret: process.env.SESSION_SECRET || 'dev-insecure-secret-change-me',
  systemPrompt: process.env.SYSTEM_PROMPT || DEFAULT_SYSTEM_PROMPT,
};

export default config;
