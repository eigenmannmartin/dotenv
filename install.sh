#!/usr/bin/env bash
# dotenv bootstrap: installs chezmoi if needed and applies this repo. Safe to re-run; entrypoint for VS Code/Codespaces dotfiles install.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v chezmoi >/dev/null 2>&1; then
  if command -v brew >/dev/null 2>&1; then
    brew install chezmoi
  else
    BINDIR="$HOME/.local/bin"
    mkdir -p "$BINDIR"
    sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$BINDIR"
    export PATH="$BINDIR:$PATH"
  fi
fi

# Persist sourceDir so a later bare `chezmoi apply` works. Without this, `--source`
# is only remembered for this one invocation and every re-apply fails with
# "stat ~/.local/share/chezmoi: no such file or directory".
# Rewritten whenever it disagrees, not merely when missing: `chezmoi init` never
# overwrites an existing config, so re-cloning this repo somewhere else would leave a
# stale sourceDir behind — install.sh's own run applies from the new path while every
# later bare `chezmoi apply` silently keeps applying the OLD checkout.
CHEZMOI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
if [ "$(sed -n 's/^sourceDir = "\(.*\)"$/\1/p' "$CHEZMOI_CFG" 2>/dev/null)" != "$REPO_DIR" ]; then
  mkdir -p "$(dirname "$CHEZMOI_CFG")"
  printf 'sourceDir = "%s"\n' "$REPO_DIR" > "$CHEZMOI_CFG"
  echo "dotenv: wrote $CHEZMOI_CFG (sourceDir -> $REPO_DIR)"
fi

# .chezmoiroot points chezmoi at home/
# --force only where chezmoi could not have prompted anyway. Managed files drift (nvim
# rewrites lazy-lock.json; local edits sit unmerged), and chezmoi then stops to ask
# diff/overwrite/skip/quit. The test is whether /dev/tty can be OPENED — that is
# literally what chezmoi does, and it is NOT the same as `[ -t 0 ]`: `./install.sh
# </dev/null` from a real terminal has no stdin tty yet /dev/tty is wide open, and
# -t 0 would silently force-overwrite your edits there. When /dev/tty really is absent
# (devcontainer / Codespaces postCreate) chezmoi aborts with exit 1 and NONE of the
# .chezmoiscripts run, so --force is the only way that path completes.
if ( exec 3</dev/tty ) 2>/dev/null; then
  chezmoi init --apply --source "$REPO_DIR"
else
  chezmoi init --apply --force --source "$REPO_DIR"
fi

echo "dotenv: applied. Dependencies are installed automatically by chezmoi"
echo "  (Homebrew on macOS; apt + official installers on Debian/Ubuntu)."
echo "Re-apply later with just: chezmoi apply"
echo "Open a fresh kitty/tmux/zsh session to see the changes."
