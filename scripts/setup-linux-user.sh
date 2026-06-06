#!/usr/bin/env bash
#
# OllamaFile per-user setup on Linux.
#
# Lifecycle: routine — first-time setup for a user on a prepared box,
# safe to re-run; idempotent.
#
# Run as your normal user, NOT with sudo. Verifies that node and docker
# are reachable as the current user, then installs Node dependencies
# and Playwright browser binaries (per-user cache; no sudo).
#
# Assumes Node is provided by nvm (or another per-user version manager)
# and is already on PATH when you run this. If you use nvm, run from an
# interactive shell so nvm is sourced.
#
# Run from the repo root:
#
#     bash scripts/setup-linux-user.sh
#
# Or pass the repo path explicitly:
#
#     bash scripts/setup-linux-user.sh /path/to/ollamafile
#
# Idempotent. Safe to re-run.

set -euo pipefail

step() { printf '\n=== %s ===\n' "$*"; }
info() { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

fail() {
    printf '\nUser setup did not complete.\n%s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Must not be root
# ---------------------------------------------------------------------------

if [ "$(id -u)" -eq 0 ]; then
    fail "Run as your normal user, NOT with sudo. System packages should already be installed via setup-linux-system.sh."
fi

# ---------------------------------------------------------------------------
# Locate the repo
# ---------------------------------------------------------------------------

REPO_DIR="${1:-$PWD}"
REPO_DIR="$(cd "$REPO_DIR" 2>/dev/null && pwd)" || fail "Repo path '$1' not found."

if [ ! -f "$REPO_DIR/package.json" ]; then
    fail "No package.json at $REPO_DIR. Pass the repo path as the first argument, or cd into the repo first."
fi

cd "$REPO_DIR"

step "Repo"
info "Working in: $(pwd)"

# ---------------------------------------------------------------------------
# Node (provided by nvm or similar; we just verify)
# ---------------------------------------------------------------------------

step "Checking Node and npm"

if ! have node; then
    fail "node not on PATH. If you use nvm, make sure you ran this from an interactive shell where nvm is sourced (or 'nvm use' first). Install nvm: https://github.com/nvm-sh/nvm."
fi
if ! have npm; then
    fail "npm not on PATH (but node is — unusual). Check your Node install."
fi

info "node:   $(node --version)"
info "npm:    $(npm --version)"

ENGINES_NODE=$(node -e "console.log(require('./package.json').engines?.node || '')" 2>/dev/null || true)
if [ -n "$ENGINES_NODE" ]; then
    info "Project's package.json engines.node: $ENGINES_NODE"
fi

# ---------------------------------------------------------------------------
# Docker (must be usable without sudo for the current user)
# ---------------------------------------------------------------------------

step "Checking Docker is usable without sudo"

if ! have docker; then
    fail "docker not on PATH. Run setup-linux-system.sh first (with sudo) to install it."
fi

if ! docker ps >/dev/null 2>&1; then
    fail "Docker is installed but not accessible without sudo. If you just ran setup-linux-system.sh, you need to log out and back in (or 'newgrp docker') so the new docker group membership takes effect."
fi

info "docker:         $(docker --version)"
info "docker compose: $(docker compose version | head -1)"

# ---------------------------------------------------------------------------
# Node dependencies
# ---------------------------------------------------------------------------

step "Installing Node dependencies (npm ci)"

npm ci

# ---------------------------------------------------------------------------
# Playwright browser binaries (per-user, no sudo)
# ---------------------------------------------------------------------------

step "Installing Playwright browser binaries"

info "Downloading Chromium to ~/.cache/ms-playwright/. No sudo, no system packages."
npx playwright install chromium

# Note: 'npx playwright install-deps' (which would install system libraries
# via apt) is intentionally NOT run. On most modern Ubuntu desktops the
# required libs are already present from Chrome / Electron / etc. If a
# test crashes with 'error while loading shared libraries: libfoo.so',
# install just that lib with plain 'sudo apt install libfoo'.

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

step "Summary"

info "node:           $(node --version)"
info "npm:            $(npm --version)"
info "docker:         $(docker --version)"
info "docker compose: $(docker compose version | head -1)"
info "playwright:     $(npx playwright --version)"

cat <<EOF

User setup complete.

Day-to-day:
  - Bring the containers up (auto-pulls the model on first run; ~1.3 GB):
      docker compose up -d --build
  - Visit http://localhost:5000
  - Run unit tests:
      npm test
  - Run UI tests (requires the server up on :5000):
      npm run test:ui

EOF
