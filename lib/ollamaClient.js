import config from '../config.js';

export class OllamaClientError extends Error {
  /**
   * @param {string} message
   * @param {'connection_refused'|'non_200'|'malformed_json'} kind
   * @param {unknown} [cause]
   */
  constructor(message, kind, cause) {
    super(message, cause != null ? { cause } : undefined);
    this.name = 'OllamaClientError';
    this.kind = kind;
  }
}

/**
 * Async generator that streams chat tokens from Ollama's /api/chat endpoint.
 *
 * @param {Array<{role: string, content: string}>} messages
 * @yields {string} token content from each streamed chunk
 */
export async function* streamChat(messages) {
  const url = `${config.ollamaHost}/api/chat`;
  const body = JSON.stringify({ model: config.ollamaModel, messages, stream: true });

  let response;
  try {
    response = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body,
    });
  } catch (err) {
    throw new OllamaClientError(
      `Cannot reach Ollama at ${url}: ${err.message}`,
      'connection_refused',
      err,
    );
  }

  if (!response.ok) {
    const text = await response.text().catch(() => '');
    throw new OllamaClientError(
      `Ollama returned HTTP ${response.status}: ${text}`,
      'non_200',
    );
  }

  const decoder = new TextDecoder();
  // Incomplete JSON line carried across read() boundaries.
  let tail = '';

  for await (const chunk of response.body) {
    const text = tail + decoder.decode(chunk, { stream: true });
    const lines = text.split('\n');
    // The last element is either empty (line ended with \n) or an incomplete line.
    tail = lines.pop();

    for (const line of lines) {
      const trimmed = line.trim();
      if (!trimmed) continue;

      let parsed;
      try {
        parsed = JSON.parse(trimmed);
      } catch (err) {
        throw new OllamaClientError(
          `Malformed JSON line from Ollama: ${trimmed}`,
          'malformed_json',
          err,
        );
      }

      const content = parsed?.message?.content;
      // Skip empty-string tokens (e.g. the final done:true sentinel chunk).
      if (content) {
        yield content;
      }
    }
  }

  // Flush any remaining bytes and process the final line if present.
  const flushed = tail + decoder.decode();
  const finalLine = flushed.trim();
  if (finalLine) {
    let parsed;
    try {
      parsed = JSON.parse(finalLine);
    } catch (err) {
      throw new OllamaClientError(
        `Malformed JSON line from Ollama: ${finalLine}`,
        'malformed_json',
        err,
      );
    }
    const content = parsed?.message?.content;
    if (content) {
      yield content;
    }
  }
}
