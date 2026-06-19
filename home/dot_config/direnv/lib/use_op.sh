#!/usr/bin/env bash
# direnv stdlib extension — auto-sourced from ~/.config/direnv/lib/*.sh
#
# use_op [OP_ACCOUNT=<acct>] NAME=op://vault/item/field ...
#   Resolves 1Password secret references at directory entry via the `op` CLI.
#   Put refs (not secrets) in a project .envrc, then `direnv allow`:
#     use_op OP_ACCOUNT=my.1password.eu \
#            RUNAI_TOKEN=op://Work/runai/token \
#            OPENAI_API_KEY=op://Work/openai/credential
#   cd in  -> Touch ID -> vars exported; cd out -> unset. Nothing secret on disk.
#   No-op (dim notice) when `op` is absent, so containers stay clean.
#   Note: this machine has multiple 1Password accounts, so set OP_ACCOUNT
#   (or pin it inline: op://<account>/vault/item/field). Run `direnv reload`
#   after rotating a secret (direnv caches until .envrc changes).
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
