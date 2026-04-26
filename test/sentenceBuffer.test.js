import { describe, it } from 'node:test';
import assert from 'node:assert/strict';
import { bufferBySentence } from '../lib/sentenceBuffer.js';

async function collect(gen) {
  const chunks = [];
  for await (const chunk of gen) chunks.push(chunk);
  return chunks;
}

async function* fromTokens(tokens) {
  for (const t of tokens) yield t;
}

describe('bufferBySentence', () => {
  it('single sentence arriving as multiple tokens → one chunk', async () => {
    const chunks = await collect(bufferBySentence(fromTokens(['Hello', ' world', '.'])));
    assert.deepEqual(chunks, ['Hello world.']);
  });

  it('two sentences → two chunks, terminator stays with first sentence', async () => {
    const chunks = await collect(
      bufferBySentence(fromTokens(['Hello world. ', 'How are you?'])),
    );
    assert.deepEqual(chunks, ['Hello world.', ' How are you?']);
  });

  it('tokens without terminator accumulate until cap then flush', async () => {
    // A single 210-char token has no terminator; the cap check fires after the
    // token is appended (buf.length 210 >= MAX_BUFFER 200) and the whole buffer
    // is flushed as one chunk.  buf is then empty so EOS yields nothing extra.
    const longToken = 'a'.repeat(210);
    const chunks = await collect(bufferBySentence(fromTokens([longToken])));
    assert.equal(chunks.length, 1);
    assert.equal(chunks[0], longToken);
  });

  it('two long un-terminated tokens flush mid-stream when combined buf hits cap', async () => {
    // 150 + 60 = 210 chars, no terminator — combined buf hits cap after second token.
    const t1 = 'a'.repeat(150);
    const t2 = 'b'.repeat(60);
    const chunks = await collect(bufferBySentence(fromTokens([t1, t2])));
    assert.equal(chunks.length, 1);
    assert.equal(chunks[0], t1 + t2);
  });

  it('non-terminated tail at end-of-stream is flushed', async () => {
    const chunks = await collect(
      bufferBySentence(fromTokens(['Hello world. ', 'Tail without terminator'])),
    );
    assert.deepEqual(chunks, ['Hello world.', ' Tail without terminator']);
  });

  it('token containing terminator mid-token splits correctly', async () => {
    // Token: "end. Next" — should emit "end." and buffer " Next".
    const chunks = await collect(bufferBySentence(fromTokens(['end. Next'])));
    assert.deepEqual(chunks, ['end.', ' Next']);
  });

  it('question mark and exclamation mark also trigger flush', async () => {
    const chunks = await collect(
      bufferBySentence(fromTokens(['Really? ', 'Yes! ', 'Indeed.'])),
    );
    assert.deepEqual(chunks, ['Really?', ' Yes!', ' Indeed.']);
  });

  it('multiple sentences in a single token', async () => {
    const chunks = await collect(
      bufferBySentence(fromTokens(['One. Two. Three.'])),
    );
    assert.deepEqual(chunks, ['One.', ' Two.', ' Three.']);
  });

  it('empty input yields nothing', async () => {
    const chunks = await collect(bufferBySentence(fromTokens([])));
    assert.deepEqual(chunks, []);
  });
});
