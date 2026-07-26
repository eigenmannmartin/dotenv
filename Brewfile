# dotenv macOS dependencies — CORE (the shell itself). Installed on every machine.
# Feature add-ons live in Brewfile.dev / Brewfile.k8s and are pulled in by
# home/.chezmoiscripts/run_onchange_after_20-install-packages.sh.tmpl according to
# DOTENV_FEATURES. Install manually with: brew bundle --file Brewfile
brew "chezmoi"
brew "tmux"
brew "atuin"
brew "oh-my-posh"
brew "fzf"
brew "ripgrep"

brew "bat"          # cat with syntax highlighting + line numbers
brew "eza"          # ls with icons, colors and git status
brew "zoxide"       # smarter cd: `z <dir>` jumps by frecency, `zi` fuzzy-picks
brew "git-delta"    # syntax-highlighted, line-numbered git diffs (git pager)
brew "zsh-autosuggestions"          # fish-like inline history suggestions
brew "zsh-fast-syntax-highlighting" # live command-line syntax coloring
brew "fd"           # fast `find`; powers fzf (Ctrl-T/Alt-C)
# fzf-tab isn't packaged in brew — the installer clones it to ~/.local/share.

# The Mac is the machine you actually look at, so the GUI terminal is core here.
# (Skipped automatically on any headless box — see is_headless in the install script.)
cask "kitty"
cask "font-fira-code-nerd-font"

# Lima runs the VMs that everything else here gets applied inside; ~/.local/bin/vm
# and ~/.lima/_templates/dotenv.yaml are useless without it.
brew "lima"
