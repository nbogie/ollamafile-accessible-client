import { test } from 'node:test';
import assert from 'node:assert/strict';
import { chromium } from 'playwright';

// Walks the Tab cycle on the page and reports each stop. Requires the
// dev server to be running at localhost:5000 (e.g. via `docker compose up`).
// Driven by Chromium — accurate for HTML5 focus order; cross-checks
// against Safari + VoiceOver still need the manual pass in
// docs/early-test-with-voice-over.md.

const BASE = process.env.UI_TEST_BASE ?? 'http://localhost:5000';

async function snapshot(page) {
  return page.evaluate(() => {
    const el = document.activeElement;
    if (!el || el === document.body || el === document.documentElement) {
      return { kind: 'outside-document' };
    }
    return {
      kind: 'element',
      tag: el.tagName.toLowerCase(),
      id: el.id || null,
      type: el.getAttribute('type'),
      ariaLabel: el.getAttribute('aria-label'),
      ariaHidden: el.getAttribute('aria-hidden'),
      tabindex: el.getAttribute('tabindex'),
      visibleText: el.textContent?.trim().slice(0, 40) ?? null,
    };
  });
}

function format(s) {
  if (s.kind === 'outside-document') return '<outside the document — browser chrome>';
  return `<${s.tag}${s.id ? ` id="${s.id}"` : ''}${s.type ? ` type="${s.type}"` : ''}>` +
    (s.ariaLabel ? `  aria-label="${s.ariaLabel}"` : '') +
    (s.ariaHidden ? `  aria-hidden="${s.ariaHidden}"` : '') +
    (s.tabindex ? `  tabindex="${s.tabindex}"` : '') +
    (s.visibleText && !s.ariaLabel ? `  text="${s.visibleText}"` : '');
}

function key(s) {
  return s.kind === 'outside-document' ? 'OUTSIDE' : (s.id || s.tag);
}

test('Tab cycle on / contains only the documented focusable elements', async () => {
  const browser = await chromium.launch();
  const page = await browser.newPage();

  try {
    await page.goto(BASE);
    // Give autofocus a tick to settle.
    await page.waitForFunction(() => document.activeElement?.id === 'prompt');

    const stops = [await snapshot(page)];
    const firstKey = key(stops[0]);

    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('Tab');
      const s = await snapshot(page);
      stops.push(s);
      // Cycle complete: we've returned to the first stop.
      if (key(s) === firstKey) break;
    }

    console.log('\nTab cycle (starting from initial focus):');
    for (const [i, s] of stops.entries()) {
      console.log(`  ${i}. ${format(s)}`);
    }
    console.log();

    // Map each stop to a stable label.
    const labels = stops.map(key);

    // Document-internal focusable elements should be exactly the prompt
    // textarea and the new-conversation button. The Send button is
    // intentionally hidden (aria-hidden + tabindex=-1); history items
    // are not yet focusable (separate backlog).
    const internal = labels.filter((k) => k !== 'OUTSIDE');
    const uniqueInternal = [...new Set(internal)];
    assert.deepStrictEqual(
      uniqueInternal,
      ['prompt', 'new-convo'],
      `Unexpected internal focusable elements: ${JSON.stringify(stops, null, 2)}`,
    );
  } finally {
    await browser.close();
  }
});
