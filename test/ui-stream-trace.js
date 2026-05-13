// Diagnostic, not a test. Streams a prompt and logs every DOM change to
// #response-live and #status with timestamps, so we can see what's happening
// at end-of-stream (when VoiceOver cuts off the last sentence).
//
// Run: node test/ui-stream-trace.js
// Requires the dev server on localhost:5000 (docker compose up).

import { chromium } from 'playwright';

const BASE = 'http://localhost:5000';

const browser = await chromium.launch();
const page = await browser.newPage();

const events = [];
page.on('console', (msg) => events.push(msg.text()));

await page.goto(BASE);

await page.evaluate(() => {
  const start = performance.now();
  const t = () => `+${(performance.now() - start).toFixed(0)}ms`;

  const responseEl = document.getElementById('response-live');
  const statusEl = document.getElementById('status');
  const alertEl = document.getElementById('alert');
  const liveAnnouncer = document.getElementById('live-announcer');

  new MutationObserver((mutations) => {
    for (const m of mutations) {
      for (const n of m.addedNodes) {
        const text = (n.textContent ?? '').slice(0, 60);
        console.log(`${t()} response-live ADD <${n.nodeName.toLowerCase()}> "${text}"`);
      }
      for (const n of m.removedNodes) {
        const text = (n.textContent ?? '').slice(0, 60);
        console.log(`${t()} response-live REMOVE <${n.nodeName.toLowerCase()}> "${text}"`);
      }
    }
  }).observe(responseEl, { childList: true });

  new MutationObserver(() => {
    console.log(`${t()} status = "${statusEl.textContent}"`);
  }).observe(statusEl, { childList: true, characterData: true, subtree: true });

  new MutationObserver(() => {
    console.log(`${t()} alert  = "${alertEl.textContent}"`);
  }).observe(alertEl, { childList: true, characterData: true, subtree: true });

  new MutationObserver(() => {
    console.log(`${t()} announcer = "${liveAnnouncer.textContent.slice(0, 60)}"`);
  }).observe(liveAnnouncer, { childList: true, characterData: true, subtree: true });
});

await page.fill('#prompt', 'Tell me five distinct short facts about cats. Use complete separate sentences. Do not combine facts in one sentence.');
await page.keyboard.press('Enter');

// Wait for stream completion: <p> child count stable for 5s.
let lastCount = -1;
let stableSince = Date.now();
const HARD_TIMEOUT = Date.now() + 90000;
while (Date.now() - stableSince < 5000) {
  if (Date.now() > HARD_TIMEOUT) throw new Error('hard timeout — stream never settled');
  const count = await page.evaluate(
    () => document.getElementById('response-live').children.length,
  );
  if (count !== lastCount) {
    lastCount = count;
    stableSince = Date.now();
  }
  await page.waitForTimeout(500);
}
// Extra half-second to capture any post-stream cleanup.
await page.waitForTimeout(500);

const finalState = await page.evaluate(() => ({
  responseLiveChildren: document.getElementById('response-live').children.length,
  responseLiveOuter: document.getElementById('response-live').outerHTML.slice(0, 200),
  statusText: document.getElementById('status').textContent,
  alertText: document.getElementById('alert').textContent,
  historyItems: document.getElementById('history').children.length,
  activeElement: document.activeElement?.id || document.activeElement?.tagName,
}));

console.log('\n=== Timeline ===');
for (const e of events) console.log(e);
console.log('\n=== Final DOM ===');
console.log(JSON.stringify(finalState, null, 2));

await browser.close();
