import { describe, it, before, after } from 'node:test';
import assert from 'node:assert/strict';
import http from 'node:http';
import { streamChat, OllamaClientError } from '../lib/ollamaClient.js';

// Override config values so the client hits our test server.
// We import config before ollamaClient so we can mutate its properties.
import config from '../config.js';

function ndjsonLine(content, done = false) {
  return JSON.stringify({ message: { role: 'assistant', content }, done }) + '\n';
}

function makeServer(handler) {
  const server = http.createServer(handler);
  return new Promise((resolve) => server.listen(0, '127.0.0.1', () => resolve(server)));
}

function serverUrl(server) {
  const { address, port } = server.address();
  return `http://${address}:${port}`;
}

async function collect(gen) {
  const tokens = [];
  for await (const token of gen) tokens.push(token);
  return tokens;
}

describe('streamChat', () => {
  describe('happy path', () => {
    let server;

    before(async () => {
      server = await makeServer((req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/x-ndjson' });
        res.write(ndjsonLine('Hello'));
        res.write(ndjsonLine(', '));
        res.write(ndjsonLine('world'));
        res.write(ndjsonLine('', true));
        res.end();
      });
      config.ollamaHost = serverUrl(server);
    });

    after(() => server.close());

    it('yields tokens from streaming response', async () => {
      const tokens = await collect(streamChat([{ role: 'user', content: 'hi' }]));
      assert.deepEqual(tokens, ['Hello', ', ', 'world']);
    });

    it('sends correct JSON body to Ollama', async () => {
      let capturedBody = '';
      const capServer = await makeServer((req, res) => {
        req.on('data', (d) => (capturedBody += d));
        req.on('end', () => {
          res.writeHead(200, { 'Content-Type': 'application/x-ndjson' });
          res.write(ndjsonLine('ok', true));
          res.end();
        });
      });
      const originalHost = config.ollamaHost;
      config.ollamaHost = serverUrl(capServer);

      const messages = [{ role: 'user', content: 'test' }];
      await collect(streamChat(messages));

      const parsed = JSON.parse(capturedBody);
      assert.equal(parsed.model, config.ollamaModel);
      assert.deepEqual(parsed.messages, messages);
      assert.equal(parsed.stream, true);

      config.ollamaHost = originalHost;
      capServer.close();
    });
  });

  describe('NDJSON split across chunks', () => {
    let server;

    before(async () => {
      // Simulate a JSON line split across two TCP chunks.
      server = await makeServer((req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/x-ndjson' });
        const line = ndjsonLine('token');
        // Write first half, then second half.
        const mid = Math.floor(line.length / 2);
        res.write(line.slice(0, mid));
        res.write(line.slice(mid));
        res.write(ndjsonLine('', true));
        res.end();
      });
      config.ollamaHost = serverUrl(server);
    });

    after(() => server.close());

    it('handles a JSON line split across read() calls', async () => {
      const tokens = await collect(streamChat([{ role: 'user', content: 'hi' }]));
      assert.ok(tokens.includes('token'), `expected 'token' in ${JSON.stringify(tokens)}`);
    });
  });

  describe('non-200 response', () => {
    let server;

    before(async () => {
      server = await makeServer((req, res) => {
        res.writeHead(503, { 'Content-Type': 'text/plain' });
        res.end('Service Unavailable');
      });
      config.ollamaHost = serverUrl(server);
    });

    after(() => server.close());

    it('throws OllamaClientError with kind non_200', async () => {
      await assert.rejects(
        () => collect(streamChat([{ role: 'user', content: 'hi' }])),
        (err) => {
          assert.ok(err instanceof OllamaClientError, 'should be OllamaClientError');
          assert.equal(err.kind, 'non_200');
          assert.ok(err.message.includes('503'), 'message should include status code');
          return true;
        },
      );
    });
  });

  describe('malformed JSON line', () => {
    let server;

    before(async () => {
      server = await makeServer((req, res) => {
        res.writeHead(200, { 'Content-Type': 'application/x-ndjson' });
        res.write('not valid json\n');
        res.end();
      });
      config.ollamaHost = serverUrl(server);
    });

    after(() => server.close());

    it('throws OllamaClientError with kind malformed_json', async () => {
      await assert.rejects(
        () => collect(streamChat([{ role: 'user', content: 'hi' }])),
        (err) => {
          assert.ok(err instanceof OllamaClientError, 'should be OllamaClientError');
          assert.equal(err.kind, 'malformed_json');
          return true;
        },
      );
    });
  });

  describe('connection refused', () => {
    before(() => {
      // Point at a port nothing is listening on.
      config.ollamaHost = 'http://127.0.0.1:1';
    });

    it('throws OllamaClientError with kind connection_refused', async () => {
      await assert.rejects(
        () => collect(streamChat([{ role: 'user', content: 'hi' }])),
        (err) => {
          assert.ok(err instanceof OllamaClientError, 'should be OllamaClientError');
          assert.equal(err.kind, 'connection_refused');
          return true;
        },
      );
    });
  });
});
