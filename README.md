# OllamaFile

A screen-reader-friendly web UI for chatting with a local Ollama model.

## For Windows users (Chad's path)

See `docs/setup-windows.md` for a screen-reader-friendly setup guide. The helper script at `scripts/setup-windows.cmd` automates first-time install and verifies each step.

## Quickstart

1. Ensure Docker Desktop is running.
2. Start the stack:
   ```
   docker compose up
   ```
3. Pre-pull the default model once (first run only):
   ```
   docker compose exec ollama ollama pull llama3.2:1b
   ```
4. Open http://localhost:5000 in your browser.
5. To stop: press Ctrl+C in the compose terminal, or run `docker compose down`.

## Environment variables

| Name             | Default                                 | Description                                            |
| ---------------- | --------------------------------------- | ------------------------------------------------------ |
| `OLLAMA_HOST`    | `http://ollama:11434`                   | Base URL of the Ollama daemon.                         |
| `OLLAMA_MODEL`   | `llama3.2:1b`                           | Model name to query.                                   |
| `SESSION_SECRET` | `dev-insecure-secret-change-me`         | express-session signing secret. Override in prod.      |
| `SYSTEM_PROMPT`  | (plain-prose assistant prompt, see `config.js`) | System prompt prepended to every conversation. |

## Status

v1 skeleton. Only placeholder endpoints (`POST /chat`, `POST /new`, `GET /history`) are wired up; they respond with HTTP 501 and a `{ todo: "..." }` body. The chat UI and Ollama client land in later tasks.
