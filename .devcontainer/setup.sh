#!/usr/bin/env bash
# postCreate for the dotenv devcontainer: apply the dotfiles, then wire git commit signing + SSH push
# to the HOST 1Password agent forwarded at $SSH_AUTH_SOCK (=/ssh-agent). No key/token enters the container.
set -uo pipefail

# 1) Apply the dotfiles (chezmoi; the package installer is container-aware + self-gating). Non-fatal:
#    even if a package step fails, we still want signing wired below.
./install.sh || echo "WARN: dotfiles apply had issues — continuing to wire git signing."

# 2) Git identity — matches the host git identity (a GitHub-verified email) for the "Verified" badge.
git config --global user.name  "Martin Eigenmann"
git config --global user.email "github@eigenmannmartin.ch"

# 3) Trust github.com so SSH push doesn't block on host-key verification (auth itself is the 1Password agent).
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
if ! grep -q '^github.com ' "$HOME/.ssh/known_hosts" 2>/dev/null; then
  ssh-keyscan -t ed25519,rsa github.com >> "$HOME/.ssh/known_hosts" 2>/dev/null || true
fi

# 4) SSH commit signing through the forwarded agent.
#    op-ssh-sign is macOS-only (absent here), so git's default signer (ssh-keygen >=8.9) signs via the
#    agent. Select the GitHub signing key out of the agent by its 1Password item name ("Github Key").
if ssh-add -L 2>/dev/null | grep -i 'github' > "$HOME/.ssh/signing_key.pub" && [ -s "$HOME/.ssh/signing_key.pub" ]; then
  git config --global gpg.format      ssh
  git config --global user.signingkey "$HOME/.ssh/signing_key.pub"
  git config --global commit.gpgsign  true
  git config --global tag.gpgsign     true
  git config --global --unset gpg.ssh.program 2>/dev/null || true   # make sure we don't inherit the macOS op-ssh-sign
  # Make our own signatures locally verifiable (git verify-commit / log --show-signature).
  printf '%s %s\n' "$(git config --global user.email)" "$(cat "$HOME/.ssh/signing_key.pub")" > "$HOME/.ssh/allowed_signers"
  git config --global gpg.ssh.allowedSignersFile "$HOME/.ssh/allowed_signers"
  echo "==> dotenv devcontainer: commit signing wired to the forwarded 1Password agent."
else
  rm -f "$HOME/.ssh/signing_key.pub"
  echo "WARN: no 'github' key in the forwarded agent — signing left off."
  echo "      Unlock 1Password on the host and confirm the agent is forwarded, then re-run: bash .devcontainer/setup.sh"
fi

echo "==> dotenv devcontainer ready. From the host, run repo commands with:  dx <cmd>   (e.g. dx git commit -m ...)"
