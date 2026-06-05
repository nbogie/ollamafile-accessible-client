import config from '../config.js';

export class OllamaClientError extends Error {
  /**
   * @param {string} message — developer-facing, includes raw response details
   * @param {'connection_refused'|'non_200'|'model_not_found'|'malformed_json'} kind
   * @param {string} userMessage — phrased for end users; safe to render in the UI
   * @param {unknown} [cause]
   */
  constructor(message, kind, userMessage, cause) {
    super(message, cause != null ? { cause } : undefined);
    this.name = 'OllamaClientError';
    this.kind = kind;
    this.userMessage = userMessage;
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
      'Cannot reach the language model server. Make sure the Ollama container is running.',
      err,
    );
  }

  if (!response.ok) {
    const text = await response.text().catch(() => '');

    // Specific case: the requested model isn't installed in the running Ollama
    // server. Ollama returns 404 with a body like
    //   {"error":"model 'llama3.2:1b' not found"}
    // Surface this as its own kind with a clearly actionable user message,
    // because "non_200" alone gives the user nothing to act on.
    const modelMatch = text.match(/model\s+['"]?([^'"\s]+)['"]?\s+not\s+found/i);
    if (response.status === 404 && modelMatch) {
      const modelName = modelMatch[1];
      throw new OllamaClientError(
        `Ollama returned HTTP 404: ${text}`,
        'model_not_found',
        `The language model "${modelName}" is not installed on the Ollama server. ` +
          `Ask the administrator to install it, or if you administer this server, run: ` +
          `docker compose exec ollama ollama pull ${modelName}`,
      );
    }

    throw new OllamaClientError(
      `Ollama returned HTTP ${response.status}: ${text}`,
      'non_200',
      `The language model server returned an error (HTTP ${response.status}). ` +
        `Try again, or check the server logs.`,
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
          'The language model server returned an unexpected response. Please try again.',
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
