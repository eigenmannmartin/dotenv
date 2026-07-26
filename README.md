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
| `ai` | Claude Code + Codex CLIs (`claude`, `codex`), via npm — implies `dev` for node |
| `docker` | docker engine + compose, so [devcontainers](#dev-containers) run in the VM itself |

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
vm new box  --profile ai                # + claude code & codex CLIs (implies dev)
vm new box  --profile docker            # + a docker engine, for devcontainers in the VM
vm resize work --cpus 8 --memory 16     # change an existing VM (disk can only grow)
vm ls | vm shell <name> | vm ssh <name> | vm stop <name> | vm rm <name>
```

`vm resize` stops the instance if it is running, edits its config, and starts it again
— Lima only lets cpus/memory/disk change while the VM is down, and it has no way to
*shrink* a disk, so asking for less than it has is an error.

`--profile` and `--features` may each be repeated and/or comma-separated; everything
unions together, de-duplicates, and is emitted in a fixed order, so `k8s vpn` and
`vpn k8s` build the identical VM. An unknown profile or feature aborts before any VM
is created.

It drives [`~/.lima/_templates/dotenv.yaml`](home/dot_lima/_templates/dotenv.yaml)
(`$LIMA_HOME/_templates` is searched first, so it resolves as `template://dotenv`),
passing the profile as a Lima `param`. The VM clones this repo on first boot and
runs `install.sh` with the matching `DOTENV_FEATURES`. A readiness probe is what
makes a failed bootstrap actually fail `vm new` — a failing Lima provision script
otherwise only logs a warning and leaves you with a half-built VM.

### Mounts — your home directory is not shared

```sh
vm new work --mount ~/code --mount ~/notes:ro   # writable unless you say :ro
vm new work --no-mounts                         # not even the defaults
printf '~/code\n~/notes:ro\n' > ~/.config/dotenv/vm-mounts   # the ones you always want
```

The template bases on `template://_images/ubuntu`, **not** `template://ubuntu` —
the latter pulls in `_default/mounts`, which shares all of `~`. That is the only way
to opt out: a child template cannot unset an inherited mount (`mounts: []` merges to
no effect), and `limactl --mount-none` is rejected when combined with `--mount`, so
it cannot be undone from the CLI either.

Two consequences worth knowing: `limactl shell` can no longer land you in the host
cwd unless that directory happens to be mounted (it warns and drops you in `$HOME`),
and **existing VMs keep the mounts they were created with** — only new ones are
affected.

### Browse through a VM's VPN

```sh
vm proxy hsg          # SOCKS5 on 127.0.0.1:1080, in the background
vm proxy lab 9090     # a second one, different port
vm proxy status       # which are up, on which ports
vm proxy stop [name]  # stop one, or all of them
vm proxy hsg --foreground
```

An SSH dynamic forward into the VM. With SOCKS5 the browser hands over the *hostname*
rather than an address, so DNS resolves inside the VM too — which is what makes
split-horizon intranet names work while the rest of the Mac stays off the VPN.

Backgrounding uses ssh's own **ControlMaster** rather than a pid file: `-M` leaves a
control socket in `~/.local/state/dotenv/`, and `-O check` / `-O exit` then query and
stop that exact connection. Nothing to go stale, and no chance of signalling an
unrelated ssh. `status` cleans up sockets whose ssh has died (the file outlives it).

## Logins that survive a rebuild

`vm new` mounts one small host directory (default `~/.local/share/dotenv/vm-logins`,
`--persist` / `--no-persist`) and
[`dotenv-persist`](home/dot_local/bin/executable_dotenv-persist) symlinks the
credential files into it. Log in once, on any VM; every VM after that starts logged
in.

```sh
dotenv-persist            # link everything (runs automatically on every chezmoi apply)
dotenv-persist status     # shared / local / not created yet
dotenv-persist add .aws/credentials
dotenv-persist unshare .config/op   # reverse it; the real file goes back to $HOME
```

Shared by default: atuin's `key` + `session`, `gh/hosts.yml`,
`.claude/.credentials.json`, and the 1Password service-account token.

Deliberately **not** shared, and worth knowing why:

- atuin's `history.db` — SQLite over a virtiofs/sshfs mount risks corruption, and it
  doesn't need sharing, since the key and session are what let `atuin sync` pull the
  same history into every VM.
- `~/.config/op` — the 1Password CLI **refuses to run** when its config directory is
  a symlink, and it has a `--config` flag but no environment variable, so there is no
  way to redirect it for every invocation. It also buys nothing: with a service
  account the token *is* the credential, and `secrets` reads that file itself.

That second one generalises — share credential **files**, not config **directories**,
and check that the tool tolerates a symlink before adding one.

Re-run it after a login: some tools replace a file by `rename()`, which swaps out the
symlink. Re-running re-captures whatever came unlinked — newer file wins, and the one
that loses is kept as `.dotenv-bak` rather than deleted.

## What's managed today

| Target | Notes |
|---|---|
| `~/.zshrc` | 1Password SSH-agent wiring (guarded), **auto-start tmux** (skipped in tmux/VS Code/devcontainers/CI), **modern CLI aliases** (eza/bat) + plugins (autosuggestions, fast-syntax-highlighting, zoxide, fzf-tab), **Esc-Esc → sudo** |
| `~/.zshenv` | `PATH` for **non-interactive** shells — read by every zsh, so `ssh vm claude` finds `~/.local/bin` |
| `~/.zprofile` | guarded Homebrew + rbenv init, + the same PATH for login shells |
| `~/.tmux.conf` | `C-a` prefix, vim nav, **Catppuccin v2** block status line (host·ip·session), **popups** (M-f sessionizer, prefix+g lazygit, prefix+Tab extrakto), resurrect/continuum, **nested-session F12 toggle + remote tint** |
| `~/.config/kitty/kitty.conf` | **opaque** (`background_opacity 1.0`), FiraCode Nerd Font, `macos_option_as_alt right` (left Option types `@{}[]`), square tabs, no cursor-trail — **host-only** |
| `~/.config/kitty/current-theme.conf` | Catppuccin-Macchiato palette (generated by `kitten themes`) — **host-only** |
| `~/.config/oh-my-posh/config.omp.json` | Catppuccin prompt: per-project **color bar**, **git status**, **transient** + **right-prompt**, **kube-context guard** |
| `~/.config/nvim` | **LazyVim** + Catppuccin Macchiato + **lang extras** (Go/Py/Docker/k8s/Helm/Dart + DAP); `lazy-lock` pinned |
| `~/.config/atuin/config.toml` | atuin shell history — **synced to the home-network server** (set `sync_address`) |
| `~/.config/{k9s,lazygit,gh-dash,direnv}` | k9s (blue skin + full logs), lazygit & gh-dash themes, direnv `use_op` secrets helper |
| `~/.config/dotenv/secrets.env` | `op://` references for [`secrets`](#secrets-into-env-vars-and-logins) — **created once, never overwritten** |
| `~/.local/bin/{secrets,dotenv-persist}` | 1Password → env/logins, and logins shared across VM rebuilds |
| `~/.lima/_templates/dotenv.yaml` + `~/.local/bin/vm` | [Lima VMs](#lima-vms) — **host-only** |

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
`secrets login atuin` (see [1Password](#1password)) — or by hand,
`atuin login -u <user> -k <key>` + `atuin sync`. One history everywhere; the login
itself survives VM rebuilds via [`dotenv-persist`](#logins-that-survive-a-rebuild).

## tmux inside tmux

Unavoidable here: a tmux on the Mac, `vm shell hsg`, and the VM's `.zshrc` starts its
own tmux. Two servers, one `C-a`, and the outer one eats every keystroke.

| Key | Goes to |
|---|---|
| `C-a <key>` | the **outer** session (the Mac's) |
| `C-a C-a <key>` | the **inner** session — sends one prefix through |
| `F12` | toggles the outer session **off entirely**; every key falls through until you press it again |

`C-a C-a` is right for a one-off (`C-a C-a c` opens a window inside). `F12` is for
when you're going to *work* in there: it unsets the outer prefix and swaps its key
table for an empty one, so even a bare `C-a` reaches the inner tmux. Whichever tmux is
outermost always wins `F12`, since it reads the terminal first — the key is never
ambiguous.

**The colour half**, because two identical status bars an inch apart are unreadable:

- While the outer session is **off**, its bar goes flat grey. That is the signal that
  your keys are landing somewhere else.
- A tmux server that is **not on the Mac** gets a lighter status background and a warm
  active-pane border, so the inner session is distinguishable at rest, without
  toggling anything. Detection is `$SSH_CONNECTION` or a `lima-*` hostname — the
  latter because `limactl shell` sets no ssh variables at all. The tmux server
  inherits whichever was true when it started and outlives the connection, so it's a
  strong hint, not proof.

## Dev Containers

**Still worth having, but for a narrower reason than when it was written.** It was
built to keep an agent's blast radius small: Claude Code on the Mac, the repo's
commands in a container. [Lima VMs](#lima-vms) now do that job better — the agent
itself runs in the VM (`vm new work --profile ai --mount ~/code`), so nothing on the
Mac is exposed, not just the command execution.

What devcontainers still do that a VM does not: give a repo a **pinned, in-repo
toolchain** that VS Code and your teammates get identically. That is orthogonal to
isolation, and it is why this stays.

Run them **inside a VM** with the `docker` feature, which installs a real docker engine
there (the devcontainer CLI shells out to `docker` specifically, so containerd is not a
substitute):

```sh
vm new work --profile docker --profile ai --mount ~/code
vm shell work
cd ~/code/myrepo && dx npm test
```

The [`devcontainer`](https://github.com/devcontainers/cli) CLI is installed, and this
repo ships a [`.devcontainer/`](.devcontainer) so a repo's `git`/build/test commands run
**inside a container** — with commit signing and push that still go through your
**host 1Password agent**, no key or token ever entering the container.

How it works:

- The container forwards the host SSH agent, exposed as `SSH_AUTH_SOCK`. Where that
  socket comes from depends on the engine: OrbStack / Docker Desktop expose the Mac's
  agent only at their magic `/run/host-services/ssh-auth.sock` (the real socket lives
  outside their VM and can't be bind-mounted), while a dockerd **inside a Lima VM** can
  mount the agent socket directly, since `ssh.forwardAgent` has already put it in that
  VM's filesystem. `dx` detects which case it's in and sets `DEVCONTAINER_SSH_SOCK`;
  `devcontainer.json` defaults to the magic path. macOS-only `op-ssh-sign` is absent
  either way, so git's default `ssh-keygen` signer signs **through the forwarded
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
and then relays that cookie into openconnect-saml's waiting callback server.
openconnect-saml then does the `auth-reply` POST that swaps the SAML token for the
real `webvpn` session cookie, which is what openconnect consumes. The session cookie
never hits your terminal.

**Automating that last inch** — load
[`browser-extension/vpn-token-relay`](browser-extension/vpn-token-relay) as an
unpacked extension in Chrome on the Mac (`chrome://extensions` → Developer mode →
Load unpacked). It watches for the token cookie on the gateway and POSTs it to the
callback itself, so the login is hands-free: open the URL, authenticate, tunnel up.
It can read cookies for the configured gateway only, and sends to loopback only.
Falling back: `cisco-vpn sso` still prints a one-click **bookmarklet**, and still
accepts a pasted token.

`cisco-vpn cookie` is the same handoff from a cookie you obtained some other way.

Ctrl-C on an SSO session logs out server-side and burns the cookie — rerun to
reconnect. And the zero-setup alternative remains: connect on the Mac with Cisco
Secure Client, since Lima's user-mode networking re-originates guest traffic as
host traffic, so the VM rides the host tunnel, DNS included.

To use the tunnel the *other* way — a browser on the Mac reaching intranet sites
through the VM — see [`vm proxy`](#browse-through-a-vms-vpn).

### Running it as a service

```sh
cisco-vpn sso vpn.unisg.ch/priv -b   # connect, then detach
cisco-vpn status [-v]                # interface, routes, DNS, traffic counters
cisco-vpn suspend                    # drop the tunnel, KEEP the session
cisco-vpn resume                     # reconnect, no browser
cisco-vpn stop                       # disconnect AND log out
cisco-vpn install-service            # resume automatically on boot (systemd)
```

All of this rides on how openconnect handles signals: **SIGINT/SIGTERM log the session
off** (the cookie dies with it), **SIGHUP disconnects without logging off** (the cookie
stays usable), and **SIGUSR1** makes it dump connection stats. So `stop` is a real
logout, while `suspend` leaves a session you can `resume` without touching a browser.
The session (host, cookie, fingerprint) is saved to
`~/.local/state/dotenv/vpn.session`, mode 0600, on the VM's own disk — deliberately
*not* in the shared login store, since that would hand one VM's VPN session to every
other VM.

`install-service` is what makes it survive a **reboot**, and it exists for one reason:
systemd stops services with SIGTERM, which openconnect treats as a clean logout — so
without a unit that sets `KillSignal=SIGHUP`, rebooting kills the very session you were
trying to keep. Sessions still expire server-side; when that happens `resume` fails and
says so, and you redo the SSO login.

`status` reads the tunnel device from `/sys/class/net/<dev>/statistics` and finds the
process by pid file, falling back to a process scan so a foreground session is still
visible (it labels which one it found). `-v` additionally sends SIGUSR1 and tails
openconnect's own report — cipher, DTLS vs TLS, reconnects.

### Restricting what goes through the tunnel

```sh
cisco-vpn sso vpn.unisg.ch/priv --routes 130.0.0.0/8
printf '10.1.0.0/16\n192.168.50.0/24\n' > ~/.config/dotenv/vpn-routes   # or set it once
cisco-vpn sso vpn.unisg.ch/priv --no-vpn-dns    # keep this VM's resolver too
```

openconnect passes the head-end's config to `vpnc-script` through the environment,
and `vpnc-script` installs one route per `CISCO_SPLIT_INC_<n>_*` triple — falling back
to a **default route through the tunnel** when `CISCO_SPLIT_INC` is unset. So
`--routes` generates a shim that overwrites those variables and then `exec`s the real
`vpnc-script`. That beats fixing up `ip route` after the fact: there's no race, and it
re-applies on every reconnect. Setting a *lower* count also masks any extra ranges the
server pushed, since the loop only reads indices below it — and it narrows a
full-tunnel group just as well as a split one.

`--no-vpn-dns` additionally unsets `INTERNAL_IP4_DNS`/`CISCO_DEF_DOMAIN`, because
`vpnc-script` otherwise replaces `resolv.conf` wholesale and sends *every* lookup in
the VM to the corporate resolver — much wider than the routes you just restricted.
The trade is that intranet hostnames stop resolving, so you'd address those by IP.

Routes are resolved from `--routes`, then `$CISCO_VPN_ROUTES`, then
`~/.config/dotenv/vpn-routes` (`#` comments allowed), and are validated before
anything connects. Applies to all three modes — plain, `sso` and `cookie`.

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
  agent wins inside containers). Lima VMs get it too — the template sets
  `ssh.forwardAgent`, so `git push` and SSH commit signing work in a VM without any
  key material ever entering it.
- Commit signing uses `gpg.format = ssh` + 1Password's `op-ssh-sign` (see
  [`git/1password-signing.gitconfig`](git/1password-signing.gitconfig)).

### Secrets into env vars and logins

[`secrets`](home/dot_local/bin/executable_secrets) resolves `op://` references at the
moment you need them — nothing is written to disk, nothing lingers in your shell:

```sh
secrets run -- terraform apply    # command runs with every ref exported
secrets shell                     # subshell with them exported
secrets get GH_TOKEN              # one value
secrets login atuin|gh|all        # drive a tool's login with them
secrets ls | secrets check
```

The map lives in `~/.config/dotenv/secrets.env` — plain `NAME=op://vault/item/field`
lines, no secret values, so it is safe to read and safe to keep. chezmoi *creates* it
once and then leaves it alone, so your edits stick.

**Auth in a headless VM**: `op` there can use neither Touch ID nor the desktop app,
so use a 1Password **service account** — drop its token in
`~/.config/dotenv/op-service-account-token` (chmod 600) and everything above is
non-interactive. `dotenv-persist` shares that file across VMs, so you paste it once,
ever. `secrets` reads it per-invocation and passes it only to `op`, so the token is
never in the ambient environment. Without one, `op` falls back to prompting.

`secrets login` runs `dotenv-persist` afterwards, so a fresh login is immediately
captured into the shared store and the next VM starts out logged in. `op` itself is
installed on first use (the signed 1Password apt repo on Debian/Ubuntu, the cask on
macOS), which keeps it off the critical path of a fast VM build.

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
