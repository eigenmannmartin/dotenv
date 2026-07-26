#!/usr/bin/env bash
# Re-link the shared logins after every apply.
#
# Runs after ~/.local/bin/dotenv-persist has itself been written (that is what the
# "after" prefix buys us), and no-ops on any machine without a shared login store —
# i.e. everywhere except a VM created by `vm new`. Not run_onchange_: the thing it
# reacts to is the mount appearing, not this file changing.
set -eu

[ -x "$HOME/.local/bin/dotenv-persist" ] || exit 0
"$HOME/.local/bin/dotenv-persist" link || echo "WARN: dotenv-persist failed — logins are VM-local" >&2

# git identity, wired up here rather than in the package step because it is only true
# once the link above exists — running it earlier would warn about a missing identity
# that arrives moments later.
#
# The value itself is deliberately not written by any script: ~/.config/git/identity
# is seeded from the host by `vm new` and shared by dotenv-persist, because a
# `git config --global user.email` set inside a VM dies with `vm rm` — which is how a
# fresh box ended up failing its first commit with "Author identity unknown". It is
# INCLUDED rather than copied, so editing that one file in the store moves every VM at
# once. git ignores an include.path pointing at nothing, which is what makes this safe
# to set unconditionally: on a Mac the identity is already in ~/.gitconfig and the
# include simply adds nothing.
command -v git >/dev/null || exit 0
_ident="${XDG_CONFIG_HOME:-$HOME/.config}/git/identity"

# Checked before writing so re-applies stay quiet, and matched against the literal ~
# we write — include.path keeps the tilde and expands it when read.
if ! git config --global --get-all include.path 2>/dev/null | grep -qxF '~/.config/git/identity'; then
  git config --global --add include.path '~/.config/git/identity'
  echo "==> ~/.gitconfig now includes ~/.config/git/identity (shared between VMs)"
fi

# --includes is required and is NOT the default: handed an explicit file (--global,
# --system, --file), git reads that file ALONE and does not follow its includes. Without
# it this warns about a missing identity that is sitting in the file we just included.
#
# Worth warning about at all because the failure it predicts lands much later, at the
# first commit, with a message that mentions none of this.
if [ -z "$(git config --global --includes user.email 2>/dev/null)" ]; then
  echo "WARN: no git identity on this box — commits will fail. Fix it for every VM at once"
  echo "      by writing $_ident, or only here with:"
  echo "      git config --global user.email you@example.com"
fi
