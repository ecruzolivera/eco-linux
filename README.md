# eco-linux

Arch Linux customization — Niri + DMS (DankMaterialShell) + your apps.

## Prerequisites

A bootable **x86_64 Arch Linux** installation, HTTPS connectivity, Git, `sudo`, `curl`,
and a normal user who owns their home and has sudo access. Run interactively.
The base install owns disks, encryption, firmware, kernels, bootloader and backups.
Disable Omarchy repositories separately; this installer refuses an active
`[omarchy]` repository and does not migrate an existing Omarchy installation.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/ecruzolivera/eco-linux/master/install.sh | bash
```

Run as your normal user, **without sudo**. The bootstrap downloads the public
repository's `master` branch to a private temporary checkout, reports its commit,
and runs the installer with terminal input restored for sudo and AUR review.
It removes only its own temporary checkout afterward. This follows the latest
published setup, not a frozen release; local changes must be pushed before the
GitHub command can use them.

There are no installation choices to configure. It installs the full desktop,
personal applications, dotfiles, runtimes, editor tools and Herdr integrations.
Package reviews, confirmations and sudo passwords remain interactive.

- Changed shipped configuration files are backed up under
  `~/.local/state/eco-linux/config-backups/` before replacement. Unrelated and
  legacy files are retained; destination directory symlinks are refused.
- Display settings use portable defaults, without hard-coded monitor connectors
  or battery thresholds.
- Active/enabled network managers and DNS settings are preserved. When no known
  manager is detected, NetworkManager is enabled for the next boot without
  disrupting current connectivity.
- Installed NVIDIA drivers are preserved. Recognized modern GPUs get open DKMS
  drivers and matching kernel headers; unknown/old GPUs are left unchanged with
  a warning to configure a suitable driver manually.
- SDDM automatically logs the target user into Niri. Changed autologin configuration
  is backed up alongside `/etc/sddm.conf.d/autologin.conf`. PAM is unchanged;
  encrypted login keyrings may still require a password to unlock.
- Local installs configure inactive UFW and Docker protections while preserving
  existing active UFW rules. SSH installs leave the firewall untouched to avoid
  locking you out; review remote-access rules separately.

For a checkout you have already cloned or reviewed:

```bash
bash /path/to/eco-linux/install.sh
```

Local checkouts are used directly, even from another working directory.
`bash install.sh --help` displays the short usage instructions.

On an existing system, review conflicts and take independent backups first.
The installer performs a full `pacman -Syu`; usual package hooks can update
kernel/initramfs/boot files. It does not itself configure partitions, encryption,
Limine, Snapper or boot entries. Limine/Snapper packages are deliberately outside
the portable profile; never register an ext4 home as Btrfs.

## What it installs

| Category         | Software                                                                                                        |
| ---------------- | --------------------------------------------------------------------------------------------------------------- |
| **WM / Shell**   | niri, DMS (DankMaterialShell)                                                                                   |
| **Terminal**     | kitty, ghostty, alacritty, tmux, zsh + oh-my-zsh                                                               |
| **Browsers**     | Firefox Developer Edition, Brave, Chromium                                                                      |
| **Editor**       | neovim (full config)                                                                                            |
| **Dev tools**    | gh, glab, docker (+ buildx, compose), chezmoi, mise, just, mise, clang/llvm, gdb, lldb, git-lfs, ruby, luarocks |
| **CLI utils**    | bat, eza, fd, fzf, ripgrep, jq, zoxide, tldr, fastfetch, diff-so-fancy, lazygit, gdu                            |
| **Files**        | yazi, nautilus, gparted, gnome-disk-utility, evince                                                             |
| **Media**        | mpv, imv, gimp, imagemagick, cava, ffmpegthumbnailer                                                            |
| **Recording**    | wf-recorder, grim, slurp, satty, libnotify                                                                      |
| **Gaming**       | steam, qbittorrent                                                                                              |
| **Network**      | NetworkManager, iwd, wl-clipboard, wiremix, socat                                                               |
| **Security**     | UFW (default-deny on new setups), gnome-keyring, fprintd; existing DNS configuration preserved                 |
| **System**       | SDDM (Niri autologin), pipewire/wireplumber, power-profiles-daemon, cups, brightnessctl, playerctl, bluetui       |
| **Fonts**        | Noto (full/CJK/emoji), FiraCode Nerd, JetBrains Mono Nerd, Font Awesome                                         |
| **Theming**      | adwaita-cursors, gnome-themes-extra, yaru-icon-theme, qt6ct, matugen                                            |
| **Personal apps** | Chrome, Claude Desktop, Slack, VS Code, Android Studio, Postman, pgAdmin, T3 Code, OpenCode Desktop, MEGAsync |
| **AUR**          | Reviewed manifests in `packages/*.aur`; Herdr/OpenCode recipe revisions in `packages/integrations.lock`         |
| **User scripts** | Herdr/tmux sessionizers, Worktrunk helpers, screenshots, recording, workspace numbers (`~/.local/bin/`)         |

## How it works

The installer sources `scripts/*.sh` in lexicographic order:

```
00-checks → 01-system → 02-yay → 03-packages → 04-sddm → 05-nvidia → 06-zsh → 07-copy-config → 08-battery → 09-docker → 10-firewall → 11-user-setup → zz-final
```

Configs are organized into payload directories:

| Directory           | Copies to              | Contents                                                                                                        |
| ------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------- |
| `xdg-config/`       | `~/.config/`           | niri, DankMaterialShell, nvim, ghostty, git, tmux, yazi, bat, bottom, chezmoi, mise, opencode, zathura, etc.    |
| `home-root-config/` | `~/`                   | Home dotfiles and shared agent skills in `.agents/skills/`                                                        |
| `local-bin/`        | `~/.local/bin/`        | `eco-tmux-sessionizer`, `eco-herdr-sessionizer`, shared launcher library, Worktrunk/screenshot/recording helpers |
| `local-share/`      | `~/.local/share/`      | Checksum-guarded Herdr/OpenCode patch assets and Herdr zsh completions                                              |
| `system-config/`    | Selected `/etc/` files | SDDM autologin template; original NVIDIA and battery settings retained as reference assets                      |
| `profiles/ernesto/` | Reference assets      | Original personal monitor/workspace/DMS display settings; not applied by the automatic setup                    |

## NVIDIA

Existing installed drivers are preserved. Known Turing+ NVIDIA GPUs use
`nvidia-open-dkms`, matching kernel headers, `nvidia-utils`, `nvidia-settings` and
`egl-wayland`. Ambiguous/older hardware is skipped with a warning to configure
a suitable driver manually. No global GPU-routing environment variables are
written and no explicit boot/initramfs changes are made. Physical GPU and resume
testing remains necessary. This installer is not a driver migration tool.

## DMS (DankMaterialShell)

Runs on top of niri as a systemd user service (`dms.service`) — bar, launcher, notifications, lock screen, OSD. Includes its own polkit agent and idle management (auto-lock / display-off / suspend with separate AC and battery profiles).

Two custom plugins are bundled under `xdg-config/DankMaterialShell/plugins/`,
enabled in `plugin_settings.json`, and placed in the main bar's center section:

- **Recording Indicator** (`recordingIndicator`): shows a recording dot while
  `wf-recorder` is running; clicking it invokes the bundled recording helper.
- **Herdr Agents** (`herdrAgents`, DMS 1.6+): one robot icon for the default local
  Herdr session. Any blocked agent makes it filled red; otherwise any done agent
  makes it filled green, any working agent makes it filled yellow, and all idle
  agents make it outlined green. Unknown/unavailable states are outlined gray;
   no agents hides the icon. Click for details; hovering shows no information.
   The icon uses native QML Pictogrammers robot shapes with 25% smaller eyes,
   without SVG textures or masks. One shared daemon listens
  to Herdr's Unix-socket events and refreshes snapshots without CLI processes per
  update. It reconnects and resynchronizes automatically, with a 60-second safety
  refresh and 10-second fallback polling when events are unavailable.

The copy module installs these local plugins without registry downloads or
modifications to Herdr. Their live counterparts are also captured in chezmoi's
`dot_config/DankMaterialShell/`; capture only the custom plugin directories,
enablement and relevant bar entries, not runtime registries or caches.

Safe plugin verification (Node and `/usr/bin/qs` required for the integration suite):

```sh
node --test xdg-config/DankMaterialShell/plugins/herdr-agents/tests/*.test.cjs
python3 tests/verify-bootstrap.py
```

Integration tests use a fake Herdr Unix-socket server/CLI and isolated, non-visual Quickshell
instances in `/tmp/opencode/`, never your live agents or running DMS shell.

## Docker

Socket activation is enabled for the next boot. New daemon configurations get
10 MB × 5-file log limits; existing configurations are preserved. Docker manages
its usual networking/upstream DNS without forcing `172.17.0.1`, altering
`systemd-resolved`, or replacing network configuration. Custom/VPN subnet
conflicts must be reviewed in existing Docker configuration. Docker group
membership grants root-equivalent privileges and takes effect after login.

## Firewall

UFW default-deny inbound, default-allow outbound. LocalSend ports opened. Docker firewall bypass prevented via `ufw-docker`.

## Configuration

Home dotfiles (`.zshrc`, `.profile`, `.bashrc`, `.vimrc`, `Xresources`, etc.) live in `home-root-config/`. XDG configs live in `xdg-config/`. Both are copied by `07-copy-config.sh`.

[chezmoi](https://chezmoi.io) is installed for personal dotfile management — see [github.com/ecruzolivera/dotfiles](https://github.com/ecruzolivera/dotfiles) (configured at `~/.config/chezmoi/chezmoi.toml`).

### gdu theme

`xdg-config/gdu/gdu.yaml` installs a static Dank palette at `~/.config/gdu/gdu.yaml`,
matching the current Ghostty theme: purple selections, lavender directories,
green sizes, and dark header/footer bars. gdu loads it automatically on launch.
Only colors are changed; scanning, sorting, and deletion behavior remain unchanged.
The palette does not automatically follow later DMS theme changes.

### Source of truth and reconciliation

The **current working user configuration is authoritative**. This repository and
chezmoi capture that configuration; neither should overwrite the live home merely
to make it match an older saved copy. The 2026-10-11 reconciliation captured 274
durable files, including the current Neovim lockfile, global skills, pinned Yazi
plugins and the tested OpenCode V2 / Herdr integration.

The original capture's payload portability adjustments are:

- Shell and Worktrunk home paths use `$HOME`; zsh's `DEFAULT_USER` uses `$USER`.
- Niri home paths and the local Herdr plugin use `__HOME__`, substituted by
  `07-copy-config.sh` for the target user's actual home.
- DMS-generated Niri includes remain optional before DMS's first startup.
  Neovim and Ghostty palette files are shipped as current default seeds.

Installer hardening additionally guards optional autostarts, uses an explicit
shell argv for lid-close commands, avoids a duplicate polkit agent, and guards
the optional Rust environment in Bash. The PWA menu helper is included with
collision-free keys. Existing personal display preferences remain in the
saved hardware reference; none of these changes were applied to the live home.

Current personal preferences, project-specific Worktrunk rules, models, providers
and permissions are retained. Monitor settings are preserved in
`profiles/ernesto/` as a reference rather than imposed on fresh installs. The global
agent rule for new repositories (`master`, without renaming existing branches) is included.
Herdr patch metadata contains
historical source-machine paths as provenance, not installation destinations.

No credentials, provider login state, OpenCode service registrations, Herdr
plugin registries, logs, sockets, build caches, dependency installations or
migration backups are shipped. Generated OpenCode package manifests/lockfiles are
also excluded. Existing `tui.json` and `tui.jsonc` are retained because they still
exist live; `cli.json` is the active V2 terminal configuration.

Git cannot record private or read-only non-executable modes. The copy module
explicitly restores `cli.json` to `0600` and the shipped Yazi plugin files to
`0444`. Deployment and user bootstrap run as the target user; existing home
ownership is never recursively rewritten.

Copying is an **overlay**, not a home-directory reset. Changed shipped files get
private backups before replacement. Extra destination files are
always preserved. Existing legacy `opencode.json`, `.zshenv`, and old OpenCode skill
directories produce warnings and are not deleted automatically. Review them
before using the new configuration: an old config can still influence settings,
and an old `.zshenv` may source a missing Rust environment.

### OpenCode V2, Neovim and Herdr

The bootstrap declares `opencode-beta` and `herdr-bin`, matching the current
installed packages. The shipped patch was verified with **OpenCode 2.0.26,
Herdr 0.9.3, integration v13**; future AUR versions are not assumed compatible.
Provider authentication must be performed separately on a new machine.

`11-user-setup.sh` now runs the normal-user bootstrap automatically: trusts and
installs global mise tools (Temurin 21, Node/npm/npx, Bun, Go), ensures a Rust
toolchain for the git-status plugin plus `rust-analyzer` and `rust-src` for Neovim,
verifies that the analyzer runs, restores the Neovim lockfile, installs the
configured Mason tools, and checks LTeX+ on Java 21. It validates
expected lock revisions from a pre-restoration snapshot and refuses existing
edited/untracked or linked editor plugin checkouts instead of discarding them.
It also validates the exact
reviewed Herdr/OpenCode versions before installing plugins or applying the
checksum-guarded patch. Required failures stop installation and mark the report
at `~/.local/state/eco-linux/user-setup.txt` incomplete. A failed package/system
stage is identified on stderr; already completed package changes are not rolled
back. No persistent passwordless pacman grant is created, even on failure.

Neovim/plugin provisioning performs downloads and executes the configured plugin
code as the user, so review the checkout before installation. No provider login,
model request or live-session restart is part of bootstrap. Herdr GitHub plugins
are confirmed interactively and verified after install; declining them does not
produce false success. Already-reviewed revisions are retained on reruns;
unfamiliar installations or local modifications are refused rather than erased.

To retry a failed user-bootstrap stage from a retained local checkout, run as the
normal user:

```bash
ECO_APPS=personal bash /absolute/path/to/eco-linux/lib/user-setup.sh /absolute/path/to/eco-linux
```

Node/Bun are declared in `xdg-config/mise/config.toml`, not copied from the source
machine. Launch OpenCode externally using the sessionizers; Neovim connects to
the newest non-archived root session for its working directory, without starting
an embedded terminal or fixing a port. Restart Neovim to load changed plugins.

Herdr integration updates can overwrite the reporting repair. Reapply manually:

```bash
node "$HOME/.local/share/herdr-opencode-fix/deploy.mjs" --apply
# To restore the recorded upstream v13 implementation:
node "$HOME/.local/share/herdr-opencode-fix/deploy.mjs" --rollback
```

Unfamiliar versions or edits are refused. Follow
`local-share/herdr-opencode-fix/README.md` for rebasing and tests; restart affected
OpenCode TUIs after replacing the integration. No automatic reapplication hook
is installed. Shell aliases/completions are captured as-is, including the live
historical OpenCode completion block; they have not been independently migrated.

### Safe verification

```bash
python3 tests/verify-bootstrap.py
python3 tests/verify-installer.py
python3 tests/package-coverage.py --check-repos --installed
```

This checks shell/Lua/JavaScript syntax, Neovim mappings/events and JSON/JSONC/TOML documents, then runs **only
the copy module** in disposable homes. It verifies contents, permissions,
home-path substitution (including spaces, `&` and `|`), Niri includes/validation,
Herdr patch checksums, repeat-copy behavior, Git-checkout permission restoration,
and preservation/warnings for an existing target (including destination file
symlinks). Optional tools are used only if already installed; nothing is
installed, authenticated or started in the real home. `verify-installer.py`
uses inert module fixtures and mocked commands for entrypoint/cwd, fresh yay,
failure/interruption, deployment/profile, GPU selection and integration refusal
tests; it never runs real system modules. `package-coverage.py` accounts for the
selected manifests and classifies source-machine omissions in
`packages/omissions.toml`; `--commands` and `--packages` are post-install checks.

`--live-manifest /path/to/private/manifest.json` additionally verifies all captured
files against a pre-reconciliation live snapshot and checks that live files,
chezmoi, system payloads and repo-local `.opencode/` settings remain unchanged.
Snapshots and backups are kept outside this repository.

Do **not** run `install.sh` as a test. Fresh-boot installation, package provisioning,
and real Herdr/Neovim interaction still need a disposable Arch machine or
user-assisted checks. **Phases 1–4 are implemented, not end-to-end certified.**
Phase 5 (clean Arch VM, different username, complete provisioning/login/rerun and
interruption checks) remains deferred, along with physical GPU/suspend validation.
Passwords, browser state/PWAs, SSH keys, project data and licensed Wonderdraft
media are not restored. `tobi-try` and unsupported hardware tools need separate
local packaging; `try-cli` is not a compatible replacement. Review the optional
package omissions against your actual daily use before calling your personal
application profile complete. No package is removed just because it is omitted.

## Customization

| Edit              | Location                                         |
| ----------------- | ------------------------------------------------ |
| Packages          | `packages/*.official`, `packages/*.aur`, `packages/integrations.lock` |
| Niri              | `xdg-config/niri/*.kdl`                          |
| Home dotfiles     | `home-root-config/`                              |
| User scripts      | `local-bin/`                                     |
| Herdr patch       | `local-share/herdr-opencode-fix/`               |
| Shared skills     | `home-root-config/.agents/skills/`              |
| Docker setup      | `scripts/09-docker.sh`                           |
| Firewall rules    | `scripts/10-firewall.sh`                         |
| System configs    | `system-config/` (NVIDIA, SDDM)                  |
| XDG configs       | `xdg-config/` (neovim, ghostty, git, tmux, etc.) |
| Personal dotfiles | chezmoi repo + `~/` dotfiles                     |
