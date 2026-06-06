# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Audience and intent

OllamaFile is a screen-reader-friendly web UI for chatting with a local Ollama model. The primary user is **Chad** — a JAWS/NVDA user on Windows 11 Home. The maintainer is **Neill** on Mac and linux, remote from Chad. Every change to the app must be evaluated against the question "does this still work cleanly with a screen reader?" — visual-only fixes are not enough.

## Commands

```
npm run dev          # node --watch server.js — restarts on file change
npm start            # plain node server.js
npm test             # runs test/ollamaClient.test.js only
npm run test:ui      # Playwright Tab-cycle check; needs server on :5000
node --test test/sentenceBuffer.test.js   # not wired into npm test
node test/ui-stream-trace.js              # diagnostic: dumps DOM mutations during a stream
```

To run a single test case inside one of those files, append `--test-name-pattern='<substring>'` to the `node --test` invocation.

Docker workflow (the normal way to run the whole stack):

```
docker compose up -d --build       # rebuild app image and start everything
docker compose up -d --build app   # rebuild ONLY the app image; leave ollama alone
docker compose logs -f app         # follow app logs
docker compose exec ollama ollama list           # inspect installed models
docker compose exec ollama ollama pull <model>   # manual pull (auto-pull handles default)
docker compose down                # stop + remove containers + network; KEEPS the ollama volume
docker compose down -v             # also deletes the named volume — re-download required next up
```

The `ollama-init` one-shot service in `docker-compose.yml` pulls `OLLAMA_MODEL` (default `llama3.2:1b`) on first `up`, so a fresh clone Just Works without a manual `ollama pull` step. The app container waits on `ollama-init` via `service_completed_successfully`.

## Architecture
The app is there to test experimental architectures to try to find good solutions to the problem.  

Here's the current architecture:

Single Express server with one streaming endpoint and a static SPA. The streaming pipeline is the load-bearing piece:

```
browser EventSource ── /chat (SSE) ── server.js
                                          │
                                          ▼
                                   bufferBySentence()      ← lib/sentenceBuffer.js
                                          │
                                          ▼
                                     streamChat()          ← lib/ollamaClient.js
                                          │
                                          ▼
                            Ollama /api/chat (NDJSON stream)
```

- **`lib/ollamaClient.js`** — async generator wrapping `fetch` to Ollama's NDJSON stream. Yields raw token strings. All failure modes throw `OllamaClientError` with a `kind` (`connection_refused` | `non_200` | `model_not_found` | `malformed_json`) and a `userMessage` phrased for end users. `server.js` forwards `userMessage` to the client; nothing else is leaked.
- **`lib/sentenceBuffer.js`** — re-chunks the token stream so each SSE event carries a complete sentence (or a 200-char forced flush). This exists because a screen reader speaking individual tokens is unintelligible — sentence-sized chunks give VoiceOver/NVDA a natural unit to announce.
- **`lib/context.js`** — in-memory `Map<sessionId, messages[]>`. No persistence, no TTL. Process restart clears everything. Conversation history is keyed by `req.sessionID` from `express-session`.
- **`server.js`** — three routes: `POST /chat` (SSE), `POST /new` (clear history), `GET /history`. Errors mid-stream are sent as `data: {"error": "..."}\n\n` events, not HTTP status codes — the response is already committed to 200 by the time we start streaming.
- **`static/index.html`** — entirely self-contained: inline `<style>`, inline `<script>`, no build step. Reads the SSE stream and appends each sentence as a `<p>` inside `#response-live`. Screen-reader announcements are paced via a throttled JS drain queue writing to a hidden `#live-announcer`, NOT by relying on `aria-live` directly on `#response-live`.

## Critical conventions

**Bump the build number.** When you edit `static/index.html`, increment `<span id="build-id">build N</span>` in the footer. The user reads this back to confirm the browser actually picked up the change — there's no other ground truth because the file is inline, no hashing, no bundler.

**The pacing knob.** In `static/index.html`, the announcer drain timing is `(words / 200) * 60 * 1000 * 1.3` ms. If VoiceOver interrupts mid-sentence, bump the multiplier (1.3 → 1.5) or reduce assumed WPM (200 → 180). If pacing feels sluggish, the other direction.

**Send button is intentionally tab-hidden.** It has `aria-hidden="true"` and `tabindex="-1"`. Screen reader / keyboard users submit via Enter in the textarea (announced in its `aria-label`). The Tab cycle is tested in `test/ui-focus.test.js` and the expected internal stops are `['prompt', 'new-convo']` — adding a new focusable element means updating that assertion.

**Mac Docker = CPU only.** Expect ~20–30s for a 5-sentence response from `llama3.2:1b` on a Mac. Not a bug. Don't treat slow streams as broken until you've waited at least 30s.

**No screen-reader test catches mid-stream interruption.** Any change to the SSE chunking, the announcer, or the pacing knob requires a manual VoiceOver pass (Safari, Cmd+F5 to toggle). The `test/ui-focus.test.js` Playwright check verifies focus order only.

## Environment

| Var              | Default                          | Notes                                                       |
| ---------------- | -------------------------------- | ----------------------------------------------------------- |
| `OLLAMA_HOST`    | `http://ollama:11434`            | Compose-internal hostname; override for non-compose runs.   |
| `OLLAMA_MODEL`   | `llama3.2:1b`                    | Read by both `app` and `ollama-init`.                       |
| `SESSION_SECRET` | `dev-insecure-secret-change-me`  | Insecure default; override in any non-dev environment.      |
| `SYSTEM_PROMPT`  | plain-prose instruction          | See `config.js`. Forbids markdown so the screen reader doesn't read out asterisks and hashes. |

## Cross-platform setup

Setup scripts under `scripts/` cover three host OSes — they're shipped to Chad (Windows) and used on Neill's Linux dev box. Touch them carefully; Chad runs them from PowerShell.

- `scripts/setup-windows.{cmd,ps1}` — first-time install for Chad's Windows 11 Home machine.
- `scripts/update-windows.{cmd,ps1}` — `git pull` + `docker compose up -d --build` for ongoing updates.
- `scripts/cleanup-port-conflicts.ps1` — kills stale containers binding 5000/11434.
- `scripts/setup-linux-system.sh` — sudo-required; installs Docker + git, adds user to docker group.
- `scripts/setup-linux-user.sh` — non-sudo; `npm ci` + Playwright Chromium install.

Detailed setup docs live in `docs/setup-windows.md` and `recommended-setup.md`.
