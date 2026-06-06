# scripts/

Helper scripts for installing, updating, and operating OllamaFile.

Each script's own header is the source of truth for what it does. This page is a directory.

## Conventions

- **`.cmd` files are thin launchers** for the matching `.ps1`. The `.ps1` carries the description; the `.cmd` just invokes PowerShell with the right flags so Chad can double-click it from Explorer. Read the `.ps1` if you want to know what a paired script actually does.
- **Lifecycle is declared in every script header**, one of:
  - *routine* — safe to run any time; idempotent. Install, update, daily start/stop.
  - *one-shot* — needed once per install; safe to delete afterwards.
  - *situational* — only when a specific problem arises (e.g. port conflict).
- **All Windows scripts read out cleanly under JAWS/NVDA**: full-sentence prompts, one step announced before its work begins, errors phrased as actions the user can take.

## Windows

| Script | Lifecycle | Purpose |
| --- | --- | --- |
| `setup-windows.cmd` / `setup-windows.ps1` | routine | First-time install. Checks Docker, builds the app image, pulls the model, sanity-checks the web app, creates a desktop shortcut. |
| `start-windows.cmd` | routine | Bring the stack up and open the browser. Daily use. |
| `stop-windows.cmd` | routine | Bring the stack down. Daily use. Preserves the model volume. |
| `update-windows.cmd` / `update-windows.ps1` | routine | `git pull` + rebuild + restart. Requires Git for Windows. |
| `apply-auto-pull-update.cmd` / `apply-auto-pull-update.ps1` | **one-shot** | Updates Chad's pre-auto-pull install over to the auto-pull `docker-compose.yml`. Uses WSL git so it works without Git for Windows. Delete after the install is current. |
| `cleanup-port-conflicts.ps1` | situational | Frees ports 5000 / 11434 by stopping/removing any container holding them. Use when `docker compose up` fails with "port already allocated". |

## Linux

| Script | Lifecycle | Purpose |
| --- | --- | --- |
| `setup-linux-system.sh` | routine | Sudo-required. Installs git + Docker, adds the invoking user to the docker group. |
| `setup-linux-user.sh` | routine | Non-sudo. Verifies node + docker are usable, runs `npm ci`, installs Playwright Chromium. |

Run them in that order on a fresh box. The system script's closing message walks through the group-membership traps (SSH ControlMaster, tmux, `newgrp`) that catch people out between the two.
