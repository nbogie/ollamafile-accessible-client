// Sentence-boundary regex: matches a sentence terminator (.  ?  !) followed by
// optional whitespace.  We keep the terminator attached to the preceding text
// (i.e. split *after* it) so the emitted chunk reads naturally.
// The lookahead `(?=\s|$)` avoids splitting on decimal points or ellipses mid-word.
const SENTENCE_END_RE = /([.?!])(?=\s|$)/;

// Maximum buffer length before a forced flush.  200 chars is a comfortable
// upper bound for a long clause or list item — long enough to avoid chopping
// mid-phrase, short enough to keep the screen-reader announcement prompt and
// not stall for a paragraph if the model never punctuates.
const MAX_BUFFER = 200;

/**
 * Async generator that wraps any string-yielding async iterable and re-emits
 * sentence-sized chunks instead of raw tokens.
 *
 * Flush conditions (in priority order):
 *   1. A sentence terminator (. ? !) followed by whitespace or end-of-string
 *      is found in the accumulated buffer — everything up to and including the
 *      terminator is emitted, the remainder stays in the buffer.
 *   2. The buffer reaches MAX_BUFFER characters — the whole buffer is flushed
 *      immediately to avoid stalling forever on unpunctuated output.
 *   3. End-of-stream — any remaining buffer content is flushed before done.
 *
 * On upstream error: the partial buffer is discarded.  Emitting an incomplete
 * sentence before an error event would confuse the screen reader, so silence
 * is preferable to a fragment.
 *
 * @param {AsyncIterable<string>} source
 * @yields {string}
 */
export async function* bufferBySentence(source) {
  let buf = '';

  for await (const token of source) {
    buf += token;

    // Keep flushing complete sentences out of the buffer until no more are found.
    let match;
    while ((match = SENTENCE_END_RE.exec(buf)) !== null) {
      const cutAt = match.index + match[0].length;
      const chunk = buf.slice(0, cutAt);
      buf = buf.slice(cutAt);
      yield chunk;
    }

    // Force-flush if the buffer has grown beyond the cap without any terminator.
    if (buf.length >= MAX_BUFFER) {
      yield buf;
      buf = '';
    }
  }

  // End-of-stream: flush whatever remains (non-terminated tail).
  if (buf.length > 0) {
    yield buf;
  }
}
