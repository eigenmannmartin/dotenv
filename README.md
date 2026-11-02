# dotenv

Personal, portable dotfiles for the Mac, the Lima VMs it runs, and any container,
managed with [chezmoi](https://www.chezmoi.io/). (The name predates the `.env`/dotenv
tooling collision — this is a *dotfiles* repo, not env-var loading.)

This page is the overview. The details live next to the code: the commands answer
`--help` (`tmux-sessionizer` and `ssh-launch` explain themselves in their headers), and
every script and config file explains itself in its header.

## Bootstrap

A new machine or container that has `git` (the plugin externals below need it even
when chezmoi could clone without it):

```sh
sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" \
  init --apply https://github.com/eigenmannmartin/dotenv.git
./install.sh      # …or this, from a local clone
```

Two details that matter on a *fresh* box: `-b ~/.local/bin` puts chezmoi somewhere
permanent and on `PATH` (the installer otherwise drops it in `./bin`, so the later
bare `chezmoi apply` would be "command not found" on Linux, where nothing else
installs chezmoi), and the **https** remote works before any SSH key exists — switch
the remote to SSH afterwards if you want to push.

chezmoi reads [`.chezmoiroot`](.chezmoiroot) and treats [`home/`](home) as the
source state (`dot_zshrc` → `~/.zshrc`, etc.). Repo-meta files at the root
(`README.md`, `install.sh`, the Brewfiles, `browser-extension/`) are *not* applied
to `$HOME`.

**Inside any container**, VS Code can bootstrap them: set
`"dotfiles.repository": "eigenmannmartin/dotenv"` (+ `"dotfiles.installCommand": "install.sh"`)
in your VS Code settings. Host-only bits skip themselves and every tool hook is
`command -v`-guarded, so a barebones image no-ops cleanly. That path gets the plain
`core` default; set `DOTENV_FEATURES` in the container's environment for more.

## Feature profiles

A throwaway VM shouldn't wait for a toolchain it will never use, so installs are
split into groups. `core` alone — the default — is just the shell:

```sh
./install.sh                                  # core: zsh, tmux, prompt, atuin, fzf…
DOTENV_FEATURES=core,devlite ./install.sh     # + neovim/LazyVim, lazygit, wt, node
DOTENV_FEATURES=core,dev ./install.sh         # + containers (OrbStack on macOS)
DOTENV_FEATURES=core,dev,k8s,vpn ./install.sh # the full workstation (ai/docker/flutter: opt in)
```

The package list ([Dependencies & platforms](#dependencies--platforms) says where each comes from):

| Feature | Adds |
|---|---|
| `core` | zsh + fzf-tab, zsh-autosuggestions, fast-syntax-highlighting, zsh-abbr; tmux + catppuccin, extrakto; oh-my-posh, atuin, fzf, ripgrep, bat, eza, zoxide, delta, fd. Linux also: kitty-terminfo + ncurses-term (kitty-terminfo is retried on every apply; where apt can't install it, e.g. without sudo, the shell falls back to `TERM=xterm-256color`). macOS also: chezmoi, kitty + FiraCode Nerd Font, lima |
| `devlite` | neovim + LazyVim config, lazygit, [worktrunk](https://github.com/max-sixty/worktrunk) (`wt`), node + pnpm + prettier, jq, yq, gh + gh-dash, direnv, btop, pre-commit, git-lfs. Linux also: python3, pipx, build-essential (a C compiler for treesitter). macOS also: mise, git-absorb, dust/duf/procs |
| `dev` | **`devlite` + the container layer**: OrbStack (macOS only), lazydocker, dive |
| `k8s` | [sofka](https://github.com/nklmilojevic/sofka) + its config, helm, helmfmt, argocd. macOS also: kubecolor, kubectx/kubens, stern. Linux also: kubectl (macOS gets it from OrbStack, so pair `k8s` with `dev` on a Mac) |
| `vpn` | Linux only: openconnect, vpnc-scripts, openconnect-saml, dig → the [`cisco-vpn`](#cisco-vpn-entra-id-sso-from-the-lima-vm) command |
| `ai` | Claude Code + Codex CLIs (`claude`, `codex`) + [Backlog.md](#backlogmd-boards) (`backlog`), via npm — needs node, so pair it with `devlite` (`DOTENV_FEATURES=core,devlite,ai`; `vm new <name> --profile ai` adds it for you) |
| `docker` | Linux only: a docker engine inside the Linux VM (apt `docker.io` + compose v2; you join the `docker` group) |
| `flutter` | macOS only: fvm + CocoaPods for Flutter/iOS work; the Flutter SDK itself is per-project (`fvm install` reads `.fvmrc`), Xcode from the App Store |

`dev` is split from `devlite` because the container half is the expensive one —
OrbStack is a ~1 GB cask with a VM behind it. On Linux `dev` installs just the clients;
the engine comes from `docker` or a remote `DOCKER_HOST`. `dev` always brings `devlite`,
so `core,dev` and `core,devlite,dev` are the same machine.

The choice is frozen into `~/.config/chezmoi/chezmoi.toml` by
[`home/.chezmoi.toml.tmpl`](home/.chezmoi.toml.tmpl), so later bare `chezmoi apply`
runs keep it; re-run `install.sh` with a new `DOTENV_FEATURES` to change it. An
unknown feature name aborts `init` rather than quietly installing less than asked. A
config written before features existed (no `features` key) is treated as `core`, and
`chezmoi init` warns about it — re-run `install.sh` with the set you want.

Gating happens in two places: [`.chezmoiignore`](home/.chezmoiignore) keeps unused
*configs* from deploying at all (a core-only box never gets `~/.config/nvim`, so
LazyVim never bootstraps), and the package step skips the matching installs. Turning a
feature off leaves its configs behind: chezmoi forgets them, it does not delete them.

## What's managed today

| Target | Notes |
|---|---|
| `~/.zshrc` | prompt + [project badge](#per-project-prompt-badge), 1Password SSH-agent wiring (guarded), eza/bat aliases, zsh plugins + **abbreviations**, fzf/atuin/zoxide/direnv/mise hooks, `wt` shell integration, **Esc-Esc → sudo** |
| `~/.zshenv`, `~/.zprofile` | `PATH` for **non-interactive** shells (`~/.local/bin`, Linux sbin, `/opt/homebrew/bin`) + `DEVELOPER_DIR` — read by every zsh, so `ssh vm claude` finds `~/.local/bin`; guarded Homebrew, rbenv and OrbStack init for login shells |
| `~/.tmux.conf` | `C-a` prefix, vim nav, **Catppuccin v2** block status line (host·ip·session), **popups**, mouse/OSC 52 copy, remote-host tint ([keys](#tmux)) |
| `~/.local/share/{fzf-tab,zsh-*}`, `~/.tmux/plugins/{catppuccin,extrakto}` | third-party plugins, cloned by chezmoi from [`.chezmoiexternal.toml`](home/.chezmoiexternal.toml) on every OS (git checkouts refreshed weekly, catppuccin pinned to a release) — no tpm, no plugin manager at runtime |
| `~/.config/kitty/` | default font (Menlo) with FiraCode Nerd Font as the icon-glyph fallback, `macos_option_as_alt right` (left Option types `@{}[]`), `#121212` background, copy-on-select, Catppuccin-Macchiato theme (generated by `kitten themes`) — **macOS only** |
| `~/.config/oh-my-posh/config.omp.json` | Catppuccin prompt: per-project **color bar**, **git status**, **transient** + **right-prompt**, **kube-context guard** |
| `~/.config/nvim` | [**LazyVim**](#neovim-lazyvim) + Catppuccin Macchiato + **lang extras**; `lazy-lock` pinned |
| `~/.config/{atuin,sofka,lazygit,gh-dash,direnv}` | atuin **synced to the home-network server** (`sync_address`), sofka (Catppuccin Macchiato skin), lazygit & gh-dash themes, direnv `use_op` secrets helper |
| `~/.config/git/ignore` | global gitignore (git reads it with no config) — currently `.backlog/` |
| `~/.config/dotenv/secrets.env` | `op://` references for [`secrets`](#secrets-into-env-vars-and-logins) — **created once, never overwritten** |
| `~/.local/bin/*` | the [commands](#commands) |
| `~/.lima/_templates/dotenv.yaml` + `~/.local/bin/vm` | [Lima VMs](#lima-vms) — **macOS only** |

## Cheat-sheets

### Shell

Modern replacements, aliased in `~/.zshrc` and guarded so a barebones container falls
back to the original command:

| Key / command | What it does |
|---|---|
| `ls` / `ll` / `la` / `lt` | [`eza`](https://eza.rocks) — icons, colors, git status; `lt` is a 2-level tree |
| `cat` | [`bat`](https://github.com/sharkdp/bat) — syntax highlighting (Catppuccin Macchiato; plain when piped) |
| _start typing_ | greyed **autosuggestion** from history (`→` or `Tab` accepts) via [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions), plus live **syntax highlighting** via [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) |
| `g` `gs` `gd` `gl` `gco` `gp` `gpl`, `k` | [zsh-abbr](https://github.com/olets/zsh-abbr) **abbreviations**: they expand in place on Space/Enter (`gs` → `git status -sb`, `k` → `kubecolor`, or `kubectl` without it), so history and atuin record the real command. Plain aliases where zsh-abbr is missing |
| `z <dir>` / `zi` | [zoxide](https://github.com/ajeetdsouza/zoxide) — smart `cd` by frecency / interactive fuzzy pick |
| `Ctrl-T` / `Alt-C` / `Tab` | fzf (**Catppuccin-themed, bat/eza previews**): insert a file / `cd` into a subdir / fuzzy completion menu (fzf-tab) |
| `Ctrl-R` | [atuin](https://atuin.sh) — one shell history, synced across machines after `secrets login atuin` ([1Password](#1password)) or `atuin login -u <user> -k <key>` |
| `Esc` `Esc` | toggle a leading `sudo` (on an empty line, prefixes the previous command) |
| `git diff` / `log` / `show` | [delta](https://dandavison.github.io/delta) — syntax-highlighted, line-numbered diffs (Catppuccin) |
| `man <cmd>` | colored man pages (rendered through bat) |
| `cd <repo>` | [direnv](https://direnv.net) + 1Password: a repo's `.envrc` loads `op://` secrets on entry, unloads on leave — nothing secret on disk (`use_op` helper) |

The **prompt** has a **transient prompt** (past lines collapse to a `❯`, red on
failure), a **right-prompt** (`✓`/`✗` exit code, exec-time when >2s, clock), and a
**kube-context guard** (`⎈ ctx:ns` — peach on a remote cluster, teal on local, hidden
when none). **`ssh`** auto-uses `kitten ssh` in a bare kitty shell (not inside tmux,
where the kitten's handshake breaks) so terminfo/colors work on every remote.

### tmux

The prefix is `C-a`. tmux never starts on its own — run `tmux`, or `tmux-sessionizer`
(the `M-f` picker) from a plain shell. On the Mac, `M-` is the **right** Option key.

| Key | What it does |
|---|---|
| `M-f` | fzf **project switcher** — pick a `~/code` project; it becomes a tmux session (lights up the color bar) |
| `M-s` | **ssh + port-forward launcher** — fzf over `~/.ssh/config` hosts + saved forwards (`~/.config/ssh-launch/targets`, a local file); opens in a named window. Type an unlisted host to ssh ad-hoc |
| `prefix`+`g` / `cmd`+`g` | **lazygit** — stage hunks, rebase, stash (`cmd+g` is the kitty overlay) |
| `prefix`+`Tab` | **extrakto** — fuzzy-grab any path / SHA / pod-name / URL off the screen |
| `prefix`+`h`/`j`/`k`/`l`, `M-←↑↓→` | move between panes |
| `prefix`+`-` / `prefix`+`\|` | split below / beside, in the pane's directory |
| `M-H` / `M-L`, `prefix`+`C-p` / `C-n`, `prefix`+`a` | previous / next window, last window (`prefix`+`L` swaps left) |
| `prefix`+`[`, then `v` … `y` | vi copy mode; `y` copies (see [below](#copy--paste)); `prefix`+`r` reloads the config |

**tmux inside tmux** (a tmux on the Mac, `vm shell hsg`, a tmux in the VM): `C-a <key>`
goes to the **outer** session, `C-a C-a <key>` to the **inner** one (`C-a C-a c` opens
a window inside). A tmux server **not on the Mac** gets a lighter status bar and a warm
active-pane border. Detection is `$SSH_CONNECTION` or a `lima-*` hostname (`limactl
shell` sets no ssh variables); the server keeps whatever was true when it started, so
it's a strong hint, not proof.

### Copy & paste

- **tmux**: drag with the mouse, or `y` in copy mode. With `set-clipboard on` tmux
  sends it to the outer terminal as OSC 52, so it reaches the Mac clipboard over ssh and
  from a Lima VM. Dragging over `less` (or any app not tracking the mouse) works too.
- **Neovim**: marking text with the mouse (drag, double-click a word, triple-click a
  line) copies it on release; keyboard `y` copies too (`unnamedplus`). On Linux with no
  `DISPLAY`/`WAYLAND_DISPLAY` (Lima VM, container, ssh box) that goes out as OSC 52, and
  `"+p` pastes nvim's own last yank — paste from the Mac with Cmd+V.
- **Scripts**: `cmd | osc52-copy` (on Linux also `pbcopy`) puts stdin on the clipboard
  of the terminal you are *looking at*.
- **kitty** (macOS): copy-on-select; hold Shift while dragging over an app that grabbed
  the mouse. `ctrl+shift+p>` then `shift+f` / `h` / `w` **copies** a path / git hash /
  word off the screen (hints); kitty's own defaults insert a path (`f`) or line (`l`) and
  open file:line (`n`).

### Dev tooling

The **`devlite`** feature ([`Brewfile.devlite`](Brewfile.devlite); also pulled in by
`dev`):

| Command | What it does |
|---|---|
| `jq` / `yq` | query & transform JSON / YAML (manifests, `-o json`, API output) — mikefarah's `yq` on both OSes |
| `gh` / `ghd` | GitHub CLI (PRs/issues/reviews) + `gh dash` TUI dashboard (Catppuccin) |
| `wt switch -c <branch>` | [worktrunk](https://github.com/max-sixty/worktrunk): a linked git **worktree** in a sibling `<repo>.<branch>` dir, and `cd` into it; `wt list`, `wt merge` (also deletes the branch), `wt remove`. Where `wt` is missing, `gwt <branch>` / `gwt-rm <branch>` do the basic create/remove with the same layout |
| `btop` | system monitor (CPU/mem/net/processes) |
| macOS only | `mise` (per-project tool versions + tasks, switches on `cd`), `git absorb` (route fixups into the right commit), `dust` / `duf` / `procs` (prettier `du` / `df` / `ps`) |

### Containers & Kubernetes

The **`dev`** and **`k8s`** features. On the Mac `docker`, `docker compose` and
`kubectl` come from OrbStack; in a Linux VM from the `docker` and `k8s` features:

| Command | What it does |
|---|---|
| `lazydocker` | TUI dashboard for Docker — containers, images, volumes, logs |
| `dive` | explore a Docker image layer by layer to find wasted space |
| `sofka` | Kubernetes TUI — any CRD, Flux/Argo actions, `X` incident view (Catppuccin Macchiato) |
| `k` | abbreviation for [kubecolor](https://github.com/kubecolor/kubecolor) (colorized `kubectl`; `kubectl` itself is aliased to it too) — plain `kubectl` where kubecolor is absent (Linux) |
| `kubectx` / `kubens`, `stern` | switch context / namespace by name; tail many pods' logs at once (macOS) |
| `helm` | install, upgrade & inspect apps packaged as Helm charts |
| `helmfmt` | format the Go-template side of a chart (`{{ if }}`/`range` indentation) without touching its YAML |
| `argocd` | Argo CD CLI; its login is shared between VMs |

### Per-project prompt badge

Folders under `~/code` (or `$DOTENV_CODE_ROOT`) get a colored badge in the prompt and
the tmux status bar (e.g. `hsg` = green, `bechterew` = blue). A `chpwd` hook sets it, so
it updates on `cd`, is correct per pane, and shows nothing outside `~/code`. Pin a color
by adding a line to `DOTENV_PROJECT_COLOR_MAP` in `~/.zshrc`; any other project gets a
stable color from the Catppuccin palette.

## Commands

Everything in [`home/dot_local/bin`](home/dot_local/bin), plus two tools from above:

| Command | For | Where | More |
|---|---|---|---|
| [`vm`](home/dot_local/bin/executable_vm) | purpose-built Lima VMs | macOS | `vm --help`, [Lima VMs](#lima-vms) |
| [`dotenv-persist`](home/dot_local/bin/executable_dotenv-persist) | logins that survive a VM rebuild | VMs (no-op elsewhere) | `dotenv-persist --help`, [below](#logins-that-survive-a-rebuild) |
| [`secrets`](home/dot_local/bin/executable_secrets) | 1Password → env vars and logins | everywhere | `secrets --help`, [below](#secrets-into-env-vars-and-logins) |
| [`cisco-vpn`](home/dot_local/bin/executable_cisco-vpn.tmpl) | Cisco AnyConnect with Entra ID SSO, headless | Linux, `vpn` | `cisco-vpn --help`, [below](#cisco-vpn-entra-id-sso-from-the-lima-vm) |
| [`osc52-copy`](home/dot_local/bin/executable_osc52-copy), `pbcopy` | stdin → your terminal's clipboard | everywhere; `pbcopy` Linux only | `osc52-copy --help` |
| [`tmux-sessionizer`](home/dot_local/bin/executable_tmux-sessionizer) | the `M-f` project switcher | everywhere | script header |
| [`ssh-launch`](home/dot_local/bin/executable_ssh-launch) | the `M-s` ssh/forward picker | everywhere | `ssh-launch --list`, script header |
| `wt` | git worktrees (worktrunk) | `devlite` | `wt --help` |
| `backlog` | markdown task boards | `ai` | [Backlog.md](#backlogmd-boards) |

## Lima VMs

[`vm`](home/dot_local/bin/executable_vm) builds purpose-specific Lima VMs on the Mac,
each bootstrapping this repo with the right feature set:

```sh
vm new scratch                          # core only — fastest build
vm new work --profile devlite --mount ~/code
vm new lab  --profile k8s --profile vpn # profiles COMBINE (same as --profile k8s,vpn)
vm new big  --profile full --cpus 8 --memory 16 --disk 120
vm resize work --cpus 8 --memory 16     # restarts it if running; disk can only grow
vm ls | vm shell <name> | vm ssh <name> [-t] [cmd] | vm start|stop|rm <name>
```

It drives [`~/.lima/_templates/dotenv.yaml`](home/dot_lima/_templates/dotenv.yaml)
(`template://dotenv`): the VM clones this repo on first boot and runs `install.sh`
with the profile's `DOTENV_FEATURES`; a readiness probe makes a failed bootstrap fail
`vm new`. Profiles, flags and the reasons: `vm --help` and the template's comments.

### Mounts — your home directory is not shared

`vm new work --mount ~/code --mount ~/notes:ro` shares just those (writable unless
`:ro`); put the ones you always want in `~/.config/dotenv/vm-mounts`, skip them with
`--no-mounts`.
Two consequences: `limactl shell` can't land you in the host cwd unless it is mounted
(it warns and drops you in `$HOME`), and **existing VMs keep the mounts they were
created with** — only new ones are affected.

### Browse through a VM's VPN

```sh
vm proxy hsg          # SOCKS5 on 127.0.0.1:1080 via that VM, in the background
vm proxy lab 9090     # a second one, different port
vm proxy status       # which are up, on which ports
vm proxy stop [name]  # stop one, or all of them
```

An SSH dynamic forward, so intranet names resolve inside the VM while the rest of the
Mac stays off the VPN. Starting is idempotent (already up is a no-op, a dead one comes
back on its previous port), so **when intranet pages stop loading**, re-run `vm proxy
hsg`. If it is up but VPN targets still don't answer, the tunnel *inside* the VM is
wedged: the watchdog from `cisco-vpn install-service` heals that, or run
`vm shell hsg cisco-vpn heal`.

## Logins that survive a rebuild

`vm new` mounts one small host directory (default `~/.local/share/dotenv/vm-logins`;
`--persist DIR` / `--no-persist`) and
[`dotenv-persist`](home/dot_local/bin/executable_dotenv-persist) symlinks the
credential files into it. Log in once, on any VM; every VM after that starts logged in.
It re-runs on every apply and every shell start, because atuin, `gh` and `claude`
replace a credential by `rename()`, which swaps the symlink for a real file.

Shared: atuin's key + session, `gh` hosts, your git identity, the 1Password
service-account token, argocd's config, and Claude Code's credentials, `.claude.json`
and transcripts. The list is `DEFAULT_PATHS` in the script, whose header and comments
say why each entry is there (and why atuin's `history.db` and `~/.config/op` are not);
add a path there, in the repo, to share another file. `dotenv-persist status` shows the
state in a VM.

**git identity**: `vm new` copies the host's `user.name`/`user.email` into
`~/.config/git/identity` in the store once, and every VM's `~/.gitconfig` includes it.
Only the identity: the Mac's own `~/.gitconfig` points commit signing at
`/Applications/1Password.app`, which a Linux guest does not have.

## 1Password

SSH auth uses the 1Password agent (`SSH_AUTH_SOCK`, only when its socket exists, so a
forwarded agent wins inside containers). Lima VMs get it through `ssh.forwardAgent`, so
`git push` works in a VM, and SSH commit signing can use the same agent, without key
material ever entering it. Commit signing on the Mac (1Password's `op-ssh-sign`) lives
in that machine's own `~/.gitconfig`; this repo does not manage it.

### Secrets into env vars and logins

[`secrets`](home/dot_local/bin/executable_secrets) resolves `op://` references at the
moment you need them — nothing is written to disk, nothing lingers in your shell:

```sh
secrets run -- terraform apply    # command runs with every ref exported
secrets run -- zsh                # …or a subshell with them (exit drops them)
secrets get GH_TOKEN              # one value
secrets login atuin|gh|all        # drive a tool's login with them
secrets ls | secrets check
```

The map is `~/.config/dotenv/secrets.env` — `NAME=op://vault/item/field` lines, no
values; chezmoi creates it once and then leaves your edits alone. In a headless VM, put
a 1Password **service account** token in `~/.config/dotenv/op-service-account-token`
(chmod 600); `dotenv-persist` shares it, so you paste it once. `op` itself is installed
on first use (1Password's apt repo on Debian/Ubuntu, the cask on macOS).

## Cisco VPN (Entra ID SSO) from the Lima VM

[`cisco-vpn`](home/dot_local/bin/executable_cisco-vpn.tmpl) connects a *headless* VM to
a Cisco AnyConnect gateway even though the SAML/Entra ID login needs a browser. It is
Linux-only — the `vpn` feature installs nothing on macOS.

```sh
cisco-vpn vpn.example.com              # external-browser SAML; open the printed URL on the Mac
cisco-vpn sso vpn.unisg.ch/priv -b     # embedded-SAML head-ends; -b detaches
cisco-vpn status | health | heal | suspend | resume | stop
cisco-vpn install-service              # resume on boot + a minutely heal watchdog
cisco-vpn sso vpn.unisg.ch/priv --routes 130.0.0.0/8   # only these through the tunnel
```

The login runs in the Mac's browser; Lima forwards the VM's loopback listener, so the
final `localhost` redirect lands back in the VM. For a hands-free `sso`, load
[`browser-extension/vpn-token-relay`](browser-extension/vpn-token-relay) unpacked in
Chrome on the Mac; otherwise `sso` offers a bookmarklet or a pasted token, and
`cisco-vpn cookie` takes a cookie obtained elsewhere. Modes, signals, the watchdog,
split routes and DNS: `cisco-vpn --help` and the script's comments.

The session is saved to `~/.local/state/dotenv/vpn.session` on the VM's own disk —
deliberately *not* in the shared login store, which would hand one VM's VPN session to
every other VM. The zero-setup alternative: connect on the Mac with Cisco Secure
Client — Lima's user-mode networking re-originates guest traffic as host traffic, so
the VM rides the host tunnel, DNS included. For the other direction (a Mac browser
reaching the intranet through the VM), see [`vm proxy`](#browse-through-a-vms-vpn).

## Neovim (LazyVim)

A [LazyVim](https://www.lazyvim.org/) config (Catppuccin Macchiato) ships to
`~/.config/nvim`. The **first `nvim` launch** installs every plugin — give it a moment,
then restart nvim; verify with `:LazyHealth`. Go, Python, Docker, k8s-YAML (+ Helm),
Dart and a DAP debugger are enabled in
[`lua/plugins/lang.lua`](home/dot_config/nvim/lua/plugins/lang.lua), Mason installs
their tools, and `lazy-lock.json` pins every plugin. Clipboard: see
[Copy & paste](#copy--paste).

The pinned LazyVim needs **Neovim ≥ 0.11.2** and a **C compiler** for treesitter. On
macOS both come with Homebrew; on Linux, where apt's Neovim is too old, `devlite`
installs the upstream release into `~/.local/opt/nvim` (linked as `~/.local/bin/nvim`)
whenever the `nvim` on `PATH` is older than that, plus `build-essential`.

## Backlog.md boards

[Backlog.md](https://github.com/MrLesk/Backlog.md) keeps a project's tasks as markdown
in the repo, with a terminal kanban board and a web UI. It comes with the `ai` feature.

```sh
backlog init "my project"                   # --no-git for a filesystem-only board
backlog board                               # kanban in the terminal
backlog browser                             # web UI on :6420
backlog config set autoOpenBrowser false    # there is no browser in a VM to open
backlog completion install --shell zsh      # init installs BASH completions
echo 'backlog/' >> .git/info/exclude        # keep the board out of the repo
```

No port forwarding needed: Lima forwards guest loopback listeners, so the board opens
at `http://localhost:6420` on the Mac (two VMs on one port collide; `--port` moves one).
`~/.zshrc` puts `~/.zsh/completions` on `fpath`. A non-MCP `init` also writes a tracked
`AGENTS.md` — exclude it too. A repo on a `--mount` keeps its board through `vm rm`; one
cloned inside the VM dies with it.

## Dependencies & platforms

`chezmoi apply` installs the packages for the [enabled features](#feature-profiles),
from idempotent scripts in [`home/.chezmoiscripts/`](home/.chezmoiscripts):

- **macOS**: `brew bundle --no-upgrade` over [`Brewfile`](Brewfile) plus the enabled,
  additive [`Brewfile.devlite`](Brewfile.devlite) / [`.dev`](Brewfile.dev) /
  [`.k8s`](Brewfile.k8s) / [`.flutter`](Brewfile.flutter). Open OrbStack once after
  install. `~/.zshenv` exports `DEVELOPER_DIR` wherever Xcode.app is installed, so
  `xcrun simctl` (the `flutter` workflow) works over ssh. helmfmt has no formula and
  comes from its GitHub release on both OSes.
- **Debian/Ubuntu**: apt for the distro packages (eza, zoxide and git-delta only where
  the release packages them, e.g. Ubuntu 24.04+), pipx/npm for a few CLIs, and upstream
  release binaries — fzf, atuin, oh-my-posh, lazygit, Neovim, yq, wt, lazydocker, dive,
  sofka, argocd, kubectl, helm, helmfmt — into `~/.local/bin` (Neovim's whole tree into
  `~/.local/opt/nvim`, linked from there) through one `install_bin` helper. It also
  makes zsh your login shell (`chsh`; opt out with `DOTENV_NO_CHSH=1`).
- **Both**: the zsh and tmux plugins come from
  [`.chezmoiexternal.toml`](home/.chezmoiexternal.toml) (needs `git` at apply time;
  `chezmoi apply -R` forces a refresh; a refresh that fails offline stops the apply,
  `chezmoi apply -k` gets past it; catppuccin is pinned to a release tag you bump by
  hand). delta is wired as git's pager.

**Not yet wired:** a portable `~/.vimrc` (plain `vim` fallback), zsh's own history
settings (`HISTSIZE`/`SAVEHIST` are unset; atuin holds the real history), and faster
startup via `compinit -C` (see the note in `dot_zshrc`).
