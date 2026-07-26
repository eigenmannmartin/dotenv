#!/usr/bin/env bash
# dotenv bootstrap: installs chezmoi if needed and applies this repo. Safe to re-run; entrypoint for VS Code/Codespaces dotfiles install.
#
# Pick what gets installed with DOTENV_FEATURES (default: core = shell only):
#   DOTENV_FEATURES=core,devlite ./install.sh  # + neovim/lazygit/node/devcontainer
#   DOTENV_FEATURES=core,dev ./install.sh      # + the container layer (OrbStack on macOS)
#   DOTENV_FEATURES=core,dev,k8s,vpn ./install.sh
# The choice is frozen into ~/.config/chezmoi/chezmoi.toml by home/.chezmoi.toml.tmpl,
# so later bare `chezmoi apply` runs keep it. Re-run with a new value to change it.
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

# No chezmoi.toml is written here on purpose: `chezmoi init` overwrites it wholesale
# a moment later. home/.chezmoi.toml.tmpl owns it — see the comment there.

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
