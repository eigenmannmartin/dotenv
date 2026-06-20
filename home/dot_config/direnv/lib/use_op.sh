#!/usr/bin/env bash
# direnv stdlib extension — auto-sourced from ~/.config/direnv/lib/*.sh
# use_op [OP_ACCOUNT=<acct>] NAME=op://vault/item/field ... — export 1Password refs on cd in, unset on cd out.
# Set OP_ACCOUNT (multiple accounts on this machine); run `direnv reload` after rotating a secret (direnv caches until .envrc changes).
use_op() {
  if ! has op; then
    log_status "op CLI not found — skipping secrets"
    return 0
  fi
  local pair name ref val
  for pair in "$@"; do
    name="${pair%%=*}"; ref="${pair#*=}"
    if [ "$name" = "OP_ACCOUNT" ]; then export OP_ACCOUNT="$ref"; continue; fi
    if val="$(op read "$ref" 2>/dev/null)" && [ -n "$val" ]; then
      export "$name=$val"
    else
      log_error "op read failed for $name ($ref) — unlock 1Password / check OP_ACCOUNT & ref"
    fi
  done
}
