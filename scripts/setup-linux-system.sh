#!/usr/bin/env bash
#
# OllamaFile dev-machine system setup (Ubuntu/Debian).
#
# Lifecycle: routine — first-time install on a fresh box, safe to re-run;
# idempotent.
#
# Installs system-wide packages: git, Docker (engine + compose plugin),
# and adds the invoking user to the docker group. Does NOT install
# Node — Node version management is left to nvm/mise/etc. in user
# space, handled by setup-linux-user.sh.
#
# Run with sudo:
#
#     sudo bash scripts/setup-linux-system.sh
#
# Or directly over SSH from a Mac:
#
#     ssh user@host 'sudo bash -s' < scripts/setup-linux-system.sh
#
# Idempotent. Safe to re-run.

set -euo pipefail

step() { printf '\n=== %s ===\n' "$*"; }
info() { printf '  %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

fail() {
    printf '\nSystem setup did not complete.\n%s\n' "$*" >&2
    exit 1
}

# ---------------------------------------------------------------------------
# Must be root, must be invoked via sudo so we know which user to enroll
# ---------------------------------------------------------------------------

if [ "$(id -u)" -ne 0 ]; then
    fail "Run with sudo. This script does system-level installs."
fi

TARGET_USER="${SUDO_USER:-}"
if [ -z "$TARGET_USER" ] || [ "$TARGET_USER" = "root" ]; then
    fail "Run via 'sudo bash ...', not as a root login shell. We need SUDO_USER to know which user to add to the docker group."
fi

if ! have apt-get; then
    fail "Only Debian/Ubuntu (apt) supported. apt-get not found."
fi

step "Distro and target user"
if [ -r /etc/os-release ]; then
    . /etc/os-release
    info "Distro: ${PRETTY_NAME:-unknown}"
fi
info "Target user for docker group: $TARGET_USER"

# ---------------------------------------------------------------------------
# Apt prerequisites
# ---------------------------------------------------------------------------

step "Installing prerequisites (git, curl, ca-certificates, gnupg)"

apt-get update -qq
DEBIAN_FRONTEND=noninteractive apt-get install -y \
    git curl ca-certificates gnupg lsb-release >/dev/null

info "git: $(git --version | awk '{print $3}')"

# ---------------------------------------------------------------------------
# Docker
# ---------------------------------------------------------------------------

step "Installing Docker"

if have docker && docker compose version >/dev/null 2>&1; then
    info "Docker already installed: $(docker --version)"
    info "Docker Compose already installed: $(docker compose version | head -1)"
else
    info "Using Docker's official convenience installer."
    curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
    sh /tmp/get-docker.sh
    rm -f /tmp/get-docker.sh
    info "Installed: $(docker --version)"
fi

# ---------------------------------------------------------------------------
# Docker group + service
# ---------------------------------------------------------------------------

step "Docker group membership"

if id -nG "$TARGET_USER" | grep -qw docker; then
    info "$TARGET_USER is already in the docker group."
else
    usermod -aG docker "$TARGET_USER"
    info "Added $TARGET_USER to docker group."
    info "$TARGET_USER must log out and back in (or run 'newgrp docker') for this to take effect."
fi

step "Docker service"

if systemctl is-active --quiet docker; then
    info "Docker service is running."
else
    systemctl enable --now docker
    info "Started and enabled."
fi

# ---------------------------------------------------------------------------
# Done
# ---------------------------------------------------------------------------

step "Summary"

info "git:            $(git --version)"
info "docker:         $(docker --version)"
info "docker compose: $(docker compose version | head -1)"

cat <<EOF

System setup complete.

Next steps:
  1. If you were just added to the docker group, you need a brand-new
     login for $TARGET_USER's shell to pick it up. Group membership is
     stamped at login time and does NOT update mid-session.

     Closing your terminal and opening a new one is enough IF that
     terminal opens a fresh ssh connection. But beware:

     a. SSH ControlMaster (~/.ssh/config 'ControlMaster auto' on the
        client) multiplexes commands over a single persistent
        connection. Reconnecting via ssh does NOT create a new
        login — it reuses the stale master, which still has the
        pre-add group list. From the client (e.g. your Mac):
              ssh -O exit $(hostname)
              ssh $(hostname)     # now a genuinely fresh login

     b. Any tmux session that existed before the group add inherits
        the stale group list for every pane, even brand-new ones.
        Kill and recreate it:
              tmux kill-server
              tmux new -A -s work

     c. 'newgrp docker' starts a sub-shell with docker active in the
        current terminal only. Useful as a one-shot, not a real fix.

     Verify with 'groups' or 'id' — docker should appear in the list.
     Then 'docker ps' should succeed without sudo.

  2. As $TARGET_USER (no sudo), run the user-level setup against your
     OllamaFile clone:
       cd /path/to/ollamafile
       bash scripts/setup-linux-user.sh

EOF
