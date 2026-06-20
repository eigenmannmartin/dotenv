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

# .chezmoiroot points chezmoi at home/
chezmoi init --apply --source "$REPO_DIR"

echo "dotenv: applied. Dependencies are installed automatically by chezmoi"
echo "  (Homebrew on macOS; apt + official installers on Debian/Ubuntu)."
echo "Open a fresh kitty/tmux/zsh session to see the changes."
