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
CHEZMOI_CFG="${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml"
if [ ! -f "$CHEZMOI_CFG" ]; then
  mkdir -p "$(dirname "$CHEZMOI_CFG")"
  printf 'sourceDir = "%s"\n' "$REPO_DIR" > "$CHEZMOI_CFG"
  echo "dotenv: wrote $CHEZMOI_CFG (sourceDir -> $REPO_DIR)"
fi

# .chezmoiroot points chezmoi at home/
chezmoi init --apply --source "$REPO_DIR"

echo "dotenv: applied. Dependencies are installed automatically by chezmoi"
echo "  (Homebrew on macOS; apt + official installers on Debian/Ubuntu)."
echo "Re-apply later with just: chezmoi apply"
echo "Open a fresh kitty/tmux/zsh session to see the changes."
