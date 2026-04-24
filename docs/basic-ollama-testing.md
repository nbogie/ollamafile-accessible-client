# Testing Ollama on its own

Quick ways to talk to the Ollama service directly, without going through the OllamaFile app.

## Prerequisites

- `docker compose up` is running (see the top-level `README.md`).
- The `ollama` service is exposed on host port `11434`, and inside the compose network as `http://ollama:11434`.

## A. Interactive chat via the built-in CLI

Pulls the model on first run if missing (~1.3GB for `llama3.2:1b`).

```
docker compose exec -it ollama ollama run llama3.2:1b
```

Type at the prompt. `/bye` to exit.

## B. Direct API calls from the host

Same API path that the OllamaFile app will use.

One-time pull (skip if you have already done A):

```
docker compose exec ollama ollama pull llama3.2:1b
```

Non-streaming one-shot:

```
curl http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role":"user","content":"say hi in one sentence"}],
    "stream": false
  }'
```

Streaming (prints NDJSON chunks live — what OllamaClient will do):

```
curl -N http://localhost:11434/api/chat \
  -H 'Content-Type: application/json' \
  -d '{
    "model": "llama3.2:1b",
    "messages": [{"role":"user","content":"say hi in one sentence"}],
    "stream": true
  }'
```

## What to expect

- CPU-only on Mac (no GPU passthrough in Docker Desktop on Apple Silicon). First token takes a few seconds; then tokens trickle.
- If tokens stream in (A, or the streaming curl), the end-to-end plumbing works.
