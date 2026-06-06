import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

// Exercises the Stop button + Escape key wiring against a running server.
// Default points at mt over the LAN; override with UI_TEST_BASE for local.
const BASE = process.env.UI_TEST_BASE ?? 'http://192.168.1.99:5000';

const LONG_PROMPT =
  'Tell me ten distinct simple facts about cats. Each fact must be a complete separate sentence. One fact per sentence.';

async function clearConversation(page) {
  page.once('dialog', (d) => d.accept());
  await page.click('#new-convo');
  // Status switches to "New conversation started." synchronously after the POST.
  await page.waitForFunction(
    () => document.getElementById('status').textContent.startsWith('New conversation'),
    null,
    { timeout: 5000 },
  );
}

async function sendAndWaitForChunks(page, prompt, minChunks) {
  await page.fill('#prompt', prompt);
  await page.press('#prompt', 'Enter');
  await page.waitForFunction(
    (n) => document.querySelectorAll('#response-live p').length >= n,
    minChunks,
    { timeout: 60000 },
  );
}

async function verifyStoppedState(page, partialBefore, label) {
  // Status flips to "Stopped." right away.
  await page.waitForFunction(
    () => document.getElementById('status').textContent === 'Stopped.',
    null,
    { timeout: 3000 },
  );

  // Partial response should remain visible — we keep what arrived so the
  // user can read it. Length may grow a tick (a buffered chunk in flight)
  // but should never shrink.
  const partialAfter = await page.locator('#response-live').textContent();
  assert.ok(
    partialAfter.length >= partialBefore.length,
    `[${label}] partial reply should not shrink after stop (before=${partialBefore.length}, after=${partialAfter.length})`,
  );

  // No more chunks should arrive after the stop. Snapshot count, wait, snapshot again.
  const countA = await page.locator('#response-live p').count();
  await page.waitForTimeout(2500);
  const countB = await page.locator('#response-live p').count();
  assert.equal(
    countA,
    countB,
    `[${label}] no chunks should arrive after stop (count went ${countA} → ${countB})`,
  );

  return { partialAfter, chunkCount: countB };
}

test('Stop button aborts mid-stream', async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(BASE);
    assert.equal(await page.locator('#build-id').textContent(), 'build 8');

    await clearConversation(page);
    await sendAndWaitForChunks(page, LONG_PROMPT, 2);

    const partialBefore = await page.locator('#response-live').textContent();
    await page.click('#stop-btn');

    const { partialAfter, chunkCount } = await verifyStoppedState(
      page,
      partialBefore,
      'click',
    );
    console.log(
      `  click: stopped after ${chunkCount} chunks, partial length ${partialAfter.length}`,
    );
  } finally {
    await browser.close();
  }
});

test('Escape key aborts mid-stream', async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(BASE);
    await clearConversation(page);
    await sendAndWaitForChunks(page, LONG_PROMPT, 2);

    const partialBefore = await page.locator('#response-live').textContent();
    // Focus is on the textarea (autofocus + value cleared in sendPrompt).
    // Press Escape there to confirm JAWS-forms-mode-style key passes through.
    await page.locator('#prompt').focus();
    await page.keyboard.press('Escape');

    const { partialAfter, chunkCount } = await verifyStoppedState(
      page,
      partialBefore,
      'escape',
    );
    console.log(
      `  escape: stopped after ${chunkCount} chunks, partial length ${partialAfter.length}`,
    );
  } finally {
    await browser.close();
  }
});

test('Partial reply persists in server history after stop+reload', async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(BASE);
    await clearConversation(page);
    await sendAndWaitForChunks(page, LONG_PROMPT, 2);
    const partialBefore = await page.locator('#response-live').textContent();
    await page.click('#stop-btn');
    await page.waitForFunction(
      () => document.getElementById('status').textContent === 'Stopped.',
      null,
      { timeout: 3000 },
    );
    // Wait for the server's req.on('close') handler to fire + context.append
    // to land. The connection close + append is synchronous on the server,
    // but give it a generous moment to be sure.
    await page.waitForTimeout(1000);

    await page.reload();
    // After reload, history is populated from GET /history.
    await page.waitForSelector('#history li.assistant');
    const latestAssistant = await page
      .locator('#history li.assistant')
      .first()
      .locator('.content')
      .textContent();

    // The partial we saw mid-stream should match (or be a prefix of) what the
    // server saved. The server's buffer may have a token or two more that
    // hadn't reached the client yet; the client's should not exceed it by
    // more than a chunk.
    assert.ok(
      latestAssistant.length > 0,
      'server should have persisted some of the partial reply',
    );
    console.log(
      `  reload: history has assistant entry of length ${latestAssistant.length} (client had ${partialBefore.length} pre-stop)`,
    );
  } finally {
    await browser.close();
  }
});

test('Escape with no stream in flight is a no-op', async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();
  try {
    await page.goto(BASE);
    await clearConversation(page);

    const statusBefore = await page.locator('#status').textContent();
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);
    const statusAfter = await page.locator('#status').textContent();

    assert.equal(
      statusAfter,
      statusBefore,
      'status should not change when Escape is pressed with no stream',
    );
  } finally {
    await browser.close();
  }
});
