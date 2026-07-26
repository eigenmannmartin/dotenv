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
