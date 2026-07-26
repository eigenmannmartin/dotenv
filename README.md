# dotenv

Personal, portable, devcontainer-aware dotfiles, managed with
[chezmoi](https://www.chezmoi.io/). (The name predates the `.env`/dotenv
tooling collision — this is a *dotfiles* repo, not env-var loading.)

## Bootstrap

A new machine (or a container with `git`):

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" \
  init --apply https://github.com/eigenmannmartin/dotenv.git
```

Two details that matter on a *fresh* box: `-b ~/.local/bin` puts chezmoi somewhere
permanent and on `PATH` (the installer otherwise drops it in `./bin`, so the later
bare `chezmoi apply` would be "command not found" on Linux, where nothing else
installs chezmoi), and the **https** remote works before any SSH key exists — switch
the remote to SSH afterwards if you want to push.

…or from a local clone:

```sh
./install.sh
```

chezmoi reads [`.chezmoiroot`](.chezmoiroot) and treats [`home/`](home) as the
source state (`dot_zshrc` → `~/.zshrc`, etc.). Repo-meta files at the root
(`README.md`, `install.sh`, `.devcontainer/`, `git/`) are *not* applied to
`$HOME`.

## Feature profiles

A throwaway VM shouldn't wait for a toolchain it will never use, so installs are
split into groups. `core` alone — the default — is just the shell:

```sh
./install.sh                                  # core: zsh, tmux, prompt, atuin, fzf…
DOTENV_FEATURES=core,dev ./install.sh         # + neovim/LazyVim, lazygit, node, jq
DOTENV_FEATURES=core,dev,k8s,vpn ./install.sh # everything
```

| Feature | Adds |
|---|---|
| `core` | zsh + plugins, tmux + tpm, terminfo, oh-my-posh, atuin, fzf/ripgrep/bat/eza/zoxide/delta/fd |
| `dev` | neovim + LazyVim config, lazygit, node, jq, direnv, btop, devcontainer CLI + `dx` (macOS also yq, gh + gh-dash, mise, git-absorb, OrbStack, dust/duf/procs) |
| `k8s` | k9s + its config (macOS also kubectx/stern/helm/kubecolor) |
| `vpn` | openconnect + openconnect-saml → the [`cisco-vpn`](#cisco-vpn-entra-id-sso-from-the-lima-vm) command |

The choice is frozen into `~/.config/chezmoi/chezmoi.toml` by
[`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl), so later bare `chezmoi apply`
runs keep it; re-run `install.sh` with a new `DOTENV_FEATURES` to change it. An
unknown feature name aborts `init` rather than quietly installing less than asked.
Machines that predate this split (config with a `sourceDir` and no `[data]`) keep
getting **everything**, so upgrading can't silently strip a working workstation —
run `DOTENV_FEATURES=core,dev ./install.sh` there once to opt into a smaller set. Gating
happens in two places: [`.chezmoiignore`](home/.chezmoiignore) keeps unused *configs*
from deploying at all (a core-only box never gets `~/.config/nvim`, so LazyVim never
bootstraps), and the
[package script](home/.chezmoiscripts/run_onchange_after_20-install-packages.sh.tmpl)
skips the matching installs. On macOS the same split applies via
[`Brewfile`](Brewfile) + [`Brewfile.dev`](Brewfile.dev) + [`Brewfile.k8s`](Brewfile.k8s).

## Lima VMs

[`vm`](home/dot_local/bin/executable_vm) builds purpose-specific Lima VMs on the
Mac, each bootstrapping this repo with the right feature set (Lima itself comes from
the core [`Brewfile`](Brewfile)):

```sh
vm new scratch                          # core only — fastest build
vm new work --profile dev
vm new hsg  --profile vpn               # the one that needs corporate VPN access
vm new lab  --profile k8s --profile vpn # profiles COMBINE (same as --profile k8s,vpn)
vm new big  --profile full --cpus 8 --memory 16 --disk 120
vm ls | vm shell <name> | vm ssh <name> | vm stop <name> | vm rm <name>
```

`--profile` and `--features` may each be repeated and/or comma-separated; everything
unions together, de-duplicates, and is emitted in a fixed order, so `k8s vpn` and
`vpn k8s` build the identical VM. An unknown profile or feature aborts before any VM
is created.

It drives [`~/.lima/_templates/dotenv.yaml`](home/dot_lima/_templates/dotenv.yaml)
(`$LIMA_HOME/_templates` is searched first, so it resolves as `template://dotenv`),
passing the profile as a Lima `param`. The VM clones this repo on first boot and
runs `install.sh` with the matching `DOTENV_FEATURES`. A readiness probe is what
makes a failed bootstrap actually fail `vm new` — a failing Lima provision script
otherwise only logs a warning and leaves you with a half-built VM. Each VM also gets
its own **atuin history**, named after the instance (see below).

## What's managed today

| Target | Notes |
|---|---|
| `~/.zshrc` | 1Password SSH-agent wiring (guarded), **auto-start tmux** (skipped in tmux/VS Code/devcontainers/CI), **modern CLI aliases** (eza/bat) + plugins (autosuggestions, fast-syntax-highlighting, zoxide, fzf-tab), **Esc-Esc → sudo** |
| `~/.zprofile` | guarded Homebrew + rbenv init |
| `~/.tmux.conf` | `C-a` prefix, vim nav, **Catppuccin v2** block status line (host·ip·session), **popups** (M-f sessionizer, prefix+g lazygit, prefix+Tab extrakto), resurrect/continuum |
| `~/.config/kitty/kitty.conf` | **opaque** (`background_opacity 1.0`), FiraCode Nerd Font, `macos_option_as_alt right` (left Option types `@{}[]`), square tabs, no cursor-trail — **host-only** |
| `~/.config/kitty/current-theme.conf` | Catppuccin-Macchiato palette (generated by `kitten themes`) — **host-only** |
| `~/.config/oh-my-posh/config.omp.json` | Catppuccin prompt: per-project **color bar**, **git status**, **transient** + **right-prompt**, **kube-context guard** |
| `~/.config/nvim` | **LazyVim** + Catppuccin Macchiato + **lang extras** (Go/Py/Docker/k8s/Helm/Dart + DAP); `lazy-lock` pinned |
| `~/.config/atuin/config.toml` | atuin shell history — **synced to the home-network server** (set `sync_address`) |
| `~/.config/{k9s,lazygit,gh-dash,direnv}` | k9s (blue skin + full logs), lazygit & gh-dash themes, direnv `use_op` secrets helper |

## Per-project prompt badge

Folders under `~/code` get a colored badge at the start of the prompt so you
always know which project you're in (e.g. `hsg` = green, `bechterew` = blue).
Colors are pinned in `~/.zshrc` via `DOTENV_PROJECT_COLOR_MAP`; any other project
gets a stable auto-assigned color from the Catppuccin palette. A `chpwd` hook
exports `DOTENV_PROJECT` / `DOTENV_PROJECT_COLOR`, which the oh-my-posh segment
reads — so it updates instantly on `cd`, is correct per pane, and shows nothing
outside `~/code`. Pin a new project by adding a line to the map.

## Terminal tools (cheat-sheet)

Modern replacements for everyday commands — aliased in `~/.zshrc`, each guarded
so a barebones container falls back to the original command:

| Command | What it does |
|---|---|
| `ls` / `ll` / `la` | [`eza`](https://eza.rocks) — `ls` with icons, colors and git status |
| `lt` | `eza` 2-level directory tree |
| `cat` | [`bat`](https://github.com/sharkdp/bat) — `cat` with syntax highlighting (Catppuccin Macchiato; plain when piped) |

**Shell amenities** (zsh, all guarded — no-op if the tool is missing):

| Key / command | What it does |
|---|---|
| _start typing_ | greyed **autosuggestion** from history (`→` accepts) via [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), plus live **syntax highlighting** via [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) |
| `z <dir>` / `zi` | [zoxide](https://github.com/ajeetdsouza/zoxide) — smart `cd` by frecency / interactive fuzzy pick |
| `Ctrl-T` / `Alt-C` / `Tab` | fzf (**Catppuccin-themed, bat/eza previews**): insert a file / `cd` into a subdir / fuzzy completion menu (`Ctrl-R` stays [atuin]) |
| `Esc` `Esc` | toggle a leading `sudo` (on an empty line, prefixes the previous command) |
| `git diff` / `log` / `show` | [delta](https://dandavison.github.io/delta) — syntax-highlighted, line-numbered diffs (Catppuccin) |
| `man <cmd>` | colored man pages (rendered through bat) |
| `cd <repo>` | [direnv](https://direnv.net) + 1Password: a repo's `.envrc` loads `op://` secrets on entry, unloads on leave — nothing secret on disk (`use_op` helper) |

[atuin]: https://atuin.sh

**tmux popups** (floating, dismiss on exit):

| Key | What it does |
|---|---|
| `M-f` | fzf **project switcher** — pick a `~/code` project; it becomes a tmux session (lights up the color bar) |
| `prefix`+`g` / `cmd`+`g` | **lazygit** — stage hunks, rebase, stash (Catppuccin + delta; `cmd+g` is the kitty overlay) |
| `prefix`+`Tab` | **extrakto** — fuzzy-grab any path / SHA / pod-name / URL off the screen |

**Prompt** also gains a **transient prompt** (past lines collapse to a `❯`, red on failure), a **right-prompt** (`✓`/`✗` exit code, exec-time when >2s, clock), and a **kube-context guard** (`⎈ ctx:ns` — peach on a remote cluster, teal on local, hidden when none). **`ssh`** auto-uses `kitten ssh` inside kitty so terminfo/colors work on every remote.

Container & Kubernetes inspection — the **`dev`** feature (lazydocker/ctop/dive, via
[`Brewfile.dev`](Brewfile.dev)) and the **`k8s`** feature (the rest, via
[`Brewfile.k8s`](Brewfile.k8s)), macOS only; `docker`, `docker compose` and `kubectl`
themselves come from OrbStack:

| Command | What it does |
|---|---|
| `lazydocker` | TUI dashboard for Docker — containers, images, volumes, logs |
| `ctop` | top-like live CPU/mem/net per running container |
| `dive` | explore a Docker image layer by layer to find wasted space |
| `k9s` | full-screen TUI for Kubernetes — Catppuccin Macchiato skin (blue-accented), configured to show full logs |
| `kubectx` | switch between Kubernetes clusters/contexts by name |
| `kubens` | switch the active Kubernetes namespace |
| `stern` | tail & color-code logs from multiple pods at once |
| `helm` | install, upgrade & inspect apps packaged as Helm charts |

**More dev tooling** — the **`dev`** feature ([`Brewfile.dev`](Brewfile.dev)); on
Linux only neovim/node/jq/direnv/btop/lazygit arrive, the rest stay macOS-only:

| Command | What it does |
|---|---|
| `k` | [kubecolor](https://github.com/kubecolor/kubecolor) — colorized `kubectl` (blue) + completion |
| `jq` / `yq` | query & transform JSON / YAML (manifests, `-o json`, API output) |
| `mise` | per-project tool versions (Go/Python/Node/Dart) + tasks; auto-switches on `cd` |
| `gh` / `ghd` | GitHub CLI (PRs/issues/reviews) + `gh dash` TUI dashboard (Catppuccin) |
| `git absorb` | auto-route fixup commits into the right history, then autosquash |
| `gwt <branch>` | spin up a linked git **worktree** in a sibling dir (`gwt-rm` removes it) |
| `dust` / `duf` / `procs` | prettier `du` / `df` / `ps` |
| `btop` | system monitor (CPU/mem/net/processes) |
| `cisco-vpn` | Cisco AnyConnect VPN with **Entra ID SSO** from the headless VM — see [below](#cisco-vpn-entra-id-sso-from-the-lima-vm) |
| kitty `ctrl+shift+p>…` | hints: grab a path (`f`), file:line (`n`), git hash (`h`), or line (`l`) off the screen |

**atuin sync** — shell history syncs to a self-hosted server on the home network.
Set `sync_address` in [`atuin/config.toml`](home/dot_config/atuin/config.toml), then
once per context: `atuin login -u <user> -k <key>` (key/pass in 1Password) + `atuin sync`.

**atuin contexts** — separate, switchable histories out of that one config, so a
scratch VM or a client project doesn't pollute your main history:

```sh
atuin-ctx            # which context is this shell in?   (default)
atuin-ctx ls         # list them
atuin-ctx work       # switch this shell to "work"
atuin-ctx -          # back to the default history
```

Each context is a full store of its own under `~/.local/share/atuin-ctx/<name>` —
isolation is total, and since each has its own encryption key, `atuin login`/`sync`
is per-context too (which is what keeps them separate on the server as well). The
switch rides on `ATUIN_DATA_DIR`, deliberately: it relocates the whole store and is
the one atuin setting where the environment beats `config.toml`, so unlike
`ATUIN_DB_PATH` it can't be silently overridden later. A machine's default context
comes from `~/.config/dotenv/atuin-ctx` — which is what `vm new` writes, giving every
VM its own history automatically.

## Dev Containers

The [`devcontainer`](https://github.com/devcontainers/cli) CLI is installed, and this
repo ships a [`.devcontainer/`](.devcontainer) so an agent (e.g. Claude Code) running
**on the host** can run a repo's `git`/build/test commands **inside a container** —
with commit signing and push that still go through your **host 1Password agent**, no
key or token ever entering the container.

How it works:

- The container forwards the host SSH agent at `/run/host-services/ssh-auth.sock`
  (OrbStack / Docker Desktop), exposed as `SSH_AUTH_SOCK`. macOS-only `op-ssh-sign`
  is absent, so git's default `ssh-keygen` signer signs **through the forwarded
  agent**; [`.devcontainer/setup.sh`](.devcontainer/setup.sh) wires
  `gpg.format=ssh` + selects your *Github Key* out of the agent.
- From the host, run repo commands through the **`dx`** wrapper
  ([`~/.local/bin/dx`](home/dot_local/bin/executable_dx)): `dx git commit -m …`,
  `dx git push`, `dx npm test`. It brings the container up on first use and
  `devcontainer exec`s into it.
- **Run signing commands in the foreground.** Signing/push pop a 1Password approval
  on the host; a backgrounded `dx git commit` gets no click and signing fails.
  (This is the "1Password for both" choice — autonomous-but-for-one-approval, not
  fully hands-off. A dedicated offline signing key would remove the popup; not used,
  to keep everything on the 1Password key.)
- **Other repos:** copy this `.devcontainer/` as a template — keep the agent mount +
  signing wiring, swap the image/features + `postCreate` for that project's toolchain.

VS Code can also bootstrap the dotfiles inside any container: set
`"dotfiles.repository": "eigenmannmartin/dotenv"`
(+ `"dotfiles.installCommand": "install.sh"`) in your VS Code settings; the host-only
bits skip themselves inside containers. That path gets the plain `core` default, so
set `DOTENV_FEATURES` in the container's environment if you want the dev toolchain —
this repo's own [`.devcontainer/setup.sh`](.devcontainer/setup.sh) defaults itself to
`core,dev` for exactly that reason. `dx` itself ships only with the `dev` feature,
since it needs the devcontainer CLI.

## Cisco VPN (Entra ID SSO) from the Lima VM

[`cisco-vpn`](home/dot_local/bin/executable_cisco-vpn.tmpl) connects this *headless*
VM to a Cisco AnyConnect gateway even though the SAML/Entra ID login needs a browser
(Linux-only — on the Mac itself a real browser and the Brewfile cover this):

```sh
cisco-vpn install          # one-time: openconnect (>= 9.00) + vpnc-scripts via apt
cisco-vpn vpn.example.com  # connect (Ctrl-C disconnects; extra args pass through)
```

openconnect's **external-browser** SAML flow prints the IdP URL (and drops it on
the Mac clipboard via OSC 52) instead of spawning a browser, then listens on
loopback port `29786` for the completion redirect. Lima auto-forwards guest
listeners to the host, so you open the URL **on the Mac**, log in to Entra ID there
(MFA and all), and the browser's final `localhost:29786` redirect lands back inside
the VM.
Requires the head-end to allow external-browser SAML
(`authentication saml external-browser`); embedded-webview-only gateways can't do
console SSO. When the session eventually expires the command exits — rerun it and
redo the browser login (there's no headless token refresh; brief network drops
reconnect on their own).

**Embedded-only head-ends** — where plain mode dies with `No SSO handler` because
the gateway forces the *embedded* AnyConnect webview (e.g. `vpn.unisg.ch`) — use
the `sso` subcommand, which still runs entirely in the VM:

```sh
sudo apt install pipx && pipx install openconnect-saml   # one-time
cisco-vpn sso vpn.unisg.ch/priv
```

[`openconnect-saml`](https://github.com/mschabhuettl/openconnect-saml) (maintained
[openconnect-sso](https://github.com/vlaci/openconnect-sso) fork) supplies the
webview openconnect lacks. Install the base package only — the `[gui]`/`[chrome]`
extras need a display.

The catch, and why `cisco-vpn sso` does more than shell out: **embedded mode never
calls back to localhost.** Unlike the external-browser flow, the ASA ends the login
on its own page (`sso-v2-login-final`) and leaves the token in the *browser* as the
cookie named by `sso-v2-token-cookie-name` — `acSamlv2Token` on HSG, and not
HttpOnly. So `cisco-vpn sso` prints the login URL (also OSC 52'd to your clipboard)
and then relays that cookie into openconnect-saml's waiting callback server, either
via a **bookmarklet** it prints for you — one click on the Mac, no typing — or from
a value you paste. openconnect-saml then does the `auth-reply` POST that swaps the
SAML token for the real `webvpn` session cookie, which is what openconnect consumes.
The session cookie never hits your terminal.

`cisco-vpn cookie` is the same handoff from a cookie you obtained some other way.

Ctrl-C on an SSO session logs out server-side and burns the cookie — rerun to
reconnect. And the zero-setup alternative remains: connect on the Mac with Cisco
Secure Client, since Lima's user-mode networking re-originates guest traffic as
host traffic, so the VM rides the host tunnel, DNS included.

## Neovim (LazyVim)

A [LazyVim](https://www.lazyvim.org/) config ships to `~/.config/nvim` (Catppuccin
Macchiato, to match the terminal). On the **first `nvim` launch** it bootstraps
`lazy.nvim` and installs every plugin — give it a moment, then restart nvim.
Verify with `:LazyHealth`. Language support — Go, Python, Docker, k8s-YAML (+ Helm
schemas), Dart, and a DAP debugger — is enabled in
[`lua/plugins/lang.lua`](home/dot_config/nvim/lua/plugins/lang.lua); Mason
auto-installs the LSPs/linters/formatters on first launch. Your own overrides also
live in `lua/plugins/` (e.g.
[`colorscheme.lua`](home/dot_config/nvim/lua/plugins/colorscheme.lua)); the committed
`lazy-lock.json` pins all plugin versions for reproducible installs.

## Host-only vs container-safe

- **Host-only** (ignored in containers via [`home/.chezmoiignore`](home/.chezmoiignore)):
  the `kitty` config (a desktop GUI terminal). The macOS-only 1Password
  `op-ssh-sign` signer is also host-only — containers fall back to signing
  through the forwarded host SSH agent (see [Dev Containers](#dev-containers)).
- **Container-safe**: zsh, tmux, vim, git config. External tools are
  `command -v`-guarded so a barebones image no-ops cleanly. The bridge into a
  container is **terminfo + the forwarded host SSH agent** — keys never enter
  the container.

## 1Password

- SSH auth uses the 1Password agent (`SSH_AUTH_SOCK`, guarded so the forwarded
  agent wins inside containers).
- Commit signing uses `gpg.format = ssh` + 1Password's `op-ssh-sign` (see
  [`git/1password-signing.gitconfig`](git/1password-signing.gitconfig)).

## Dependencies & platforms

`chezmoi apply` installs the packages for the machine's
[enabled features](#feature-profiles) automatically — no separate step. `core` is
the default, so a plain apply installs the shell and nothing else:

- **macOS**: Homebrew via [`Brewfile`](Brewfile) (core: tmux, atuin, oh-my-posh,
  fzf, ripgrep, bat, eza, zoxide, git-delta, fd, the two zsh plugins, + casks
  kitty & FiraCode Nerd Font, + **lima** for the VMs).
  [`Brewfile.dev`](Brewfile.dev) adds neovim, node, jq/yq, gh, mise, direnv,
  lazygit, dust/duf/procs/btop and **OrbStack** + lazydocker/ctop/dive;
  [`Brewfile.k8s`](Brewfile.k8s) adds k9s/kubecolor/kubectx/stern/helm. OrbStack
  replaces Docker Desktop and provides the `docker`/`docker compose`/`kubectl`
  CLIs; open the app once after install to finish CLI + helper setup.
- **Debian/Ubuntu**: `apt` for the core set — zsh/tmux/git/ripgrep/fzf/bat (+ `eza`,
  `zoxide`, `git-delta` on 24.04+) — plus official installers for atuin &
  oh-my-posh; kitty + Nerd Font on desktops only (skipped in containers and on
  headless VMs). `dev` adds neovim/python3/nodejs/jq/btop/direnv from apt and
  lazygit from its GitHub release; `k8s` adds k9s the same way; `vpn` adds
  openconnect + vpnc-scripts + openconnect-saml. **`yq`, `gh`, `mise`,
  `git-absorb` and the container tools remain macOS-only** — install them from
  Homebrew-on-Linux or upstream releases if you want them in a VM. LazyVim needs
  Neovim ≥ 0.9 (0.10+ recommended) and a C compiler for treesitter; on older
  Ubuntu install a newer `nvim` + `build-essential`.
- **tpm + tmux plugins**, plus the zsh plugins not in package managers
  (**fzf-tab**, and on Linux autosuggestions + fast-syntax-highlighting), are
  cloned to `~/.local/share` on both. git-delta is wired as git's pager.

Installers are idempotent, self-gating (GUI bits skipped in containers), and live
in [`home/.chezmoiscripts/`](home/.chezmoiscripts). On a fresh Ubuntu workstation
you may still want `chsh -s "$(which zsh)"` to make zsh your login shell.

## Follow-ups (not yet wired)

- More aliases / abbreviations (e.g. zsh-abbr)
- Portable `~/.vimrc` (plain `vim` fallback; Neovim/LazyVim already wired)
- zsh history tuning (fast `compinit -C` available — see the note in `dot_zshrc`)
