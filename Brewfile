# dotenv macOS dependencies. Installed automatically by `chezmoi apply`
# (see home/.chezmoiscripts/run_onchange_after_20-install-packages.sh.tmpl),
# or manually with:  brew bundle --file Brewfile
brew "chezmoi"
brew "tmux"
brew "atuin"
brew "oh-my-posh"
brew "fzf"
brew "ripgrep"
brew "neovim"       # editor — LazyVim config shipped to ~/.config/nvim
brew "node"         # runtime for some LSPs (yaml/k8s schema validation in nvim)

# Host GUI terminal + programming font (skipped inside containers by the installer)
cask "kitty"
cask "font-fira-code-nerd-font"

# Container runtime — OrbStack (fast, light Docker Desktop replacement on Apple
# Silicon). Bundles its own `docker`, `docker compose` and `kubectl`, so no
# separate docker CLI formulae are needed. macOS-host only. First run is
# interactive (open OrbStack.app once to install its CLI symlinks + privileged
# helper); brew can't fully automate that step.
cask "orbstack"

# --- Modern CLI replacements (aliased in ~/.zshrc, guarded) ----------------
brew "bat"          # cat with syntax highlighting + line numbers
brew "eza"          # ls with icons, colors and git status
brew "zoxide"       # smarter cd: `z <dir>` jumps by frecency, `zi` fuzzy-picks
brew "git-delta"    # syntax-highlighted, line-numbered git diffs (git pager)
brew "zsh-autosuggestions"          # fish-like inline history suggestions
brew "zsh-fast-syntax-highlighting" # live command-line syntax coloring
brew "fd"           # fast `find`; powers fzf (Ctrl-T/Alt-C) + nvim's picker
brew "direnv"       # per-directory env; loads op:// secrets on cd (use_op helper)
# (fzf-tab isn't packaged in brew — the installer clones it to ~/.local/share)

# --- Container & Kubernetes investigation ---------------------------------
# docker / docker compose / kubectl already come from OrbStack (above); these
# add inspection UIs + helpers on top. Cheat-sheet in README.
brew "lazygit"      # TUI for git — stage hunks, rebase, stash (prefix+g / cmd+g)
brew "lazydocker"   # TUI dashboard for Docker (containers, images, logs)
brew "ctop"         # top-like live CPU/mem/net per container
brew "dive"         # inspect a Docker image layer by layer
brew "k9s"          # TUI dashboard for Kubernetes clusters
brew "kubectx"      # switch kube contexts + namespaces (installs kubens)
brew "stern"        # tail logs across many Kubernetes pods at once
brew "helm"         # Kubernetes package manager (charts)
