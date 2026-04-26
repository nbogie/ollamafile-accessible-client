# Early test with VoiceOver

A quick manual accessibility pass for OllamaFile using macOS's built-in VoiceOver.
"Early" because it's a smoke test, not the full audit — and because NVDA + Chrome
on Windows is the canonical screen-reader target for the v1 user. Run this on
Mac during development; do the Windows pass before shipping to Chad.

## Setup

- Bring the app up: `docker compose up -d --build app`
- Open **Safari** at <http://localhost:5000/>
- Toggle VoiceOver: **Cmd+F5** (same key turns it off)
- VoiceOver's modifier key (the **VO** key) = **Ctrl+Option** by default. So
  "VO+U" below means **Ctrl+Option+U**.

## The pass

### 1. Landmarks & headings

- Press **VO+U** to open the Rotor.
- Use **left/right arrows** to switch category. Check:
  - **Landmarks** lists `main · OllamaFile chat`.
  - **Headings** lists `OllamaFile` (h1), `Current response` (h2),
    `Conversation history` (h2).
- **Esc** to close the rotor.

### 2. Tab order & labels

- **Tab** through the page. Expect, in order:
  1. The prompt textarea — announced as
     "Prompt — press Enter to send, edit text".
  2. **New conversation** button.
  3. **One unannounced stop** outside the document (browser chrome —
     toolbar / page-itself / sidebar). VoiceOver may stay silent here
     and the URL bar won't be reachable for typing. Confirmed via the
     Chromium-driven test in `test/ui-focus.test.js`; this is browser
     behaviour, not our HTML.
  4. Tab again wraps back to the prompt textarea.
- The visible **Send** button is intentionally removed from the tab
  order and hidden from VoiceOver, since Enter in the textarea is the
  primary submit path and VoiceOver's per-focus hint
  ("To click this button press control-option-space") gets noisy
  for what would otherwise be the most-focused button on the page.
  Sighted mouse users still see and click it.
- Each focusable element should show a clear blue focus ring
  (the `:focus-visible` style).
- The unannounced chrome stop becomes less annoying once the
  conversation history items are themselves Tab-focusable — that's the
  separate backlog item in `[[471f288]]`.

### Re-announcing the focused item

If you miss what VoiceOver said, you don't need to Tab away and back:

- **VO+Z** (Ctrl+Option+Z) — repeat the last spoken phrase.
- **VO+F4** (Ctrl+Option+F4) — describe the item with keyboard focus
  (re-reads name, role, hint).

### 3. Golden path — polite announcements

- Focus the textarea, type `Say hi in one short sentence.`, press **Enter**.
- VoiceOver should announce "Thinking…" (from `role="status"`).
- Tokens should stream and be spoken. Choppy is expected for now —
  sentence-level chunk buffering is task `[[2d791f6]]`.
- When done, VoiceOver says "Done (Xs)." and focus returns to the textarea.

### 4. Error path — assertive announcement

This is the test for `role="alert"` interrupting polite speech.

- In a terminal: `docker compose stop ollama`
- Send another prompt.
- VoiceOver should announce **"Error: connection_refused"** promptly —
  even mid-sentence on something else, it should interrupt.
- Restart Ollama: `docker compose start ollama`

### 5. New conversation

- Tab to the **New conversation** button, press **Space** or **Enter**.
- A confirm dialog appears — VoiceOver reads it. Press **Return** to confirm.
- VoiceOver announces "New conversation started." Focus returns to the textarea.

### 6. Done

- **Cmd+F5** to turn VoiceOver off.

## What to look for

- Did landmarks and headings show up in the Rotor?
- Did the **error** announcement actually interrupt mid-stream
  (the assertive bit)?
- Anything VoiceOver said that was confusing, missing, or read in an
  unexpected order?

## Out of scope here

- **NVDA + Chrome on Windows** — the primary target. Schedule before shipping.
- **Sentence-level chunk buffering** — task `[[2d791f6]]`. Token-by-token
  announcement is intentionally choppy until that lands.
- **Tab through history items** — captured in the project Backlog
  `[[471f288]]`.
