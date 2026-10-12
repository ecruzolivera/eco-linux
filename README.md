# eco-linux

Arch Linux customization — Niri + DMS (DankMaterialShell) + your apps.

## Prerequisites

A minimal Arch Linux installation with a non-root sudo user and internet.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/ecruzolivera/eco-linux/master/install.sh | bash
```

## What it installs

| Category         | Software                                                                                                        |
| ---------------- | --------------------------------------------------------------------------------------------------------------- |
| **WM / Shell**   | niri, DMS (DankMaterialShell)                                                                                   |
| **Terminal**     | kitty, ghostty, alacritty, tmux, zsh + oh-my-zsh                                                               |
| **Browsers**     | Firefox Developer Edition, Brave, Chromium                                                                      |
| **Editor**       | neovim (full config)                                                                                            |
| **Dev tools**    | gh, glab, docker (+ buildx, compose), chezmoi, mise, just, mise, clang/llvm, gdb, lldb, git-lfs, ruby, luarocks |
| **CLI utils**    | bat, eza, fd, fzf, ripgrep, jq, zoxide, tldr, fastfetch, diff-so-fancy, lazygit                                 |
| **Files**        | yazi, nautilus, gparted, gnome-disk-utility, evince                                                             |
| **Media**        | mpv, imv, gimp, imagemagick, cava, ffmpegthumbnailer                                                            |
| **Recording**    | wf-recorder, grim, slurp, satty, libnotify                                                                      |
| **Gaming**       | steam, qbittorrent                                                                                              |
| **Network**      | NetworkManager, iwd, wl-clipboard, wiremix, socat                                                               |
| **Security**     | UFW (default-deny), systemd-resolved (DNS-over-TLS), gnome-keyring, fprintd                                     |
| **System**       | SDDM (auto-login), pipewire/wireplumber, power-profiles-daemon, cups, brightnessctl, playerctl, bluetui         |
| **Fonts**        | Noto (full/CJK/emoji), FiraCode Nerd, JetBrains Mono Nerd, Font Awesome                                         |
| **Theming**      | adwaita-cursors, gnome-themes-extra, yaru-icon-theme, qt6ct, matugen                                            |
| **AUR**          | opencode-beta (V2), herdr-bin, brave-bin, localsend-bin, megasync-bin, riskie-bin, worktrunk-bin, limine-snapper-sync |
| **User scripts** | Herdr/tmux sessionizers, Worktrunk helpers, screenshots, recording, workspace numbers (`~/.local/bin/`)         |

## How it works

The installer sources `scripts/*.sh` in lexicographic order:

```
00-checks → 01-system → 02-yay → 03-packages → 04-sddm → 05-nvidia → 06-zsh → 07-copy-config → 08-battery → 09-docker → 10-firewall → zz-final
```

Configs are organized into payload directories:

| Directory           | Copies to              | Contents                                                                                                        |
| ------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------- |
| `xdg-config/`       | `~/.config/`           | niri, DankMaterialShell, nvim, ghostty, git, tmux, yazi, bat, bottom, chezmoi, mise, opencode, zathura, etc.    |
| `home-root-config/` | `~/`                   | Home dotfiles and shared agent skills in `.agents/skills/`                                                        |
| `local-bin/`        | `~/.local/bin/`        | `eco-tmux-sessionizer`, `eco-herdr-sessionizer`, shared launcher library, Worktrunk/screenshot/recording helpers |
| `local-share/`      | `~/.local/share/`      | Checksum-guarded Herdr/OpenCode patch assets and Herdr zsh completions                                              |
| `system-config/`    | `/etc/`, `/usr/share/` | NVIDIA env vars, SDDM session/autologin, battery charge limit service                                           |

## NVIDIA

If detected: `nvidia-dkms`, `nvidia-utils`, `nvidia-settings`, `egl-wayland` are installed. Environment variables (`GBM_BACKEND`, `__GLX_VENDOR_LIBRARY_NAME`, `LIBVA_DRIVER_NAME`) set in `/etc/environment`. Early KMS via `nvidia_drm modeset=1` and initramfs module loading enabled.

## DMS (DankMaterialShell)

Runs on top of niri as a systemd user service (`dms.service`) — bar, launcher, notifications, lock screen, OSD. Includes its own polkit agent and idle management (auto-lock / display-off / suspend with separate AC and battery profiles).

## Docker

Socket-activated (starts on demand), log limits (10 MB × 5 files), DNS passthrough via systemd-resolved at `172.17.0.1`, auto-adds user to `docker` group, doesn't block boot without network.

## Firewall

UFW default-deny inbound, default-allow outbound. LocalSend ports opened. Docker firewall bypass prevented via `ufw-docker`.

## Configuration

Home dotfiles (`.zshrc`, `.profile`, `.bashrc`, `.vimrc`, `Xresources`, etc.) live in `home-root-config/`. XDG configs live in `xdg-config/`. Both are copied by `07-copy-config.sh`.

[chezmoi](https://chezmoi.io) is installed for personal dotfile management — see [github.com/ecruzolivera/dotfiles](https://github.com/ecruzolivera/dotfiles) (configured at `~/.config/chezmoi/chezmoi.toml`).

### Source of truth and reconciliation

The **current working user configuration is authoritative**. This repository and
chezmoi capture that configuration; neither should overwrite the live home merely
to make it match an older saved copy. The 2026-10-11 reconciliation captured 274
durable files, including the current Neovim lockfile, global skills, pinned Yazi
plugins and the tested OpenCode V2 / Herdr integration.

The only payload content adjustments are:

- Shell and Worktrunk home paths use `$HOME`; zsh's `DEFAULT_USER` uses `$USER`.
- Niri home paths and the local Herdr plugin use `__HOME__`, substituted by
  `07-copy-config.sh` for the target user's actual home.
- DMS-generated Niri includes remain optional before DMS's first startup.
  Neovim and Ghostty palette files are shipped as current default seeds.

Current personal preferences, project-specific Worktrunk rules, models, providers,
permissions and monitor settings are retained. Review hardware-specific display
settings when installing on another computer. Herdr patch metadata contains
historical source-machine paths as provenance, not installation destinations.

No credentials, provider login state, OpenCode service registrations, Herdr
plugin registries, logs, sockets, build caches, dependency installations or
migration backups are shipped. Generated OpenCode package manifests/lockfiles are
also excluded. Existing `tui.json` and `tui.jsonc` are retained because they still
exist live; `cli.json` is the active V2 terminal configuration.

Git cannot record private or read-only non-executable modes. The copy module
explicitly restores `cli.json` to `0600` and the shipped Yazi plugin files to
`0444`; final setup assigns the new skills/local-share payloads to the target user.

Copying is an **overlay**, not a home-directory reset. Extra destination files are
preserved. Existing legacy `opencode.json`, `.zshenv`, and old OpenCode skill
directories produce warnings and are not deleted automatically. Review them
before using the new configuration: an old config can still influence settings,
and an old `.zshenv` may source a missing Rust environment.

### OpenCode V2, Neovim and Herdr

The bootstrap declares `opencode-beta` and `herdr-bin`, matching the current
installed packages. The shipped patch was verified with **OpenCode 2.0.26,
Herdr 0.9.3, integration v13**; future AUR versions are not assumed compatible.
Provider authentication must be performed separately on a new machine.

After installation, as the normal user:

```bash
# Install the runtimes declared by the current mise configuration.
mise install

# Review/trust these plugins before linking or installing them. Their resolved
# source revisions reproduce the current installation; registries are generated.
herdr plugin link "$HOME/.config/herdr/plugins/local/eco-ws-number" --enabled
herdr plugin install ezcorp-org/herdr-git-status --ref f144c8dac2860e344b6b379d2bcfee229dcf10ad
herdr plugin install mike-bronner/herdr-plugin-recent-spaces --ref 88d6f0590ba5e44c7f0ae3167462aa2b27178f38

node "$HOME/.local/share/herdr-opencode-fix/deploy.mjs" --check
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
```

This checks shell/Lua/JavaScript syntax, Neovim mappings/events and JSON/JSONC/TOML documents, then runs **only
the copy module** in disposable homes. It verifies contents, permissions,
home-path substitution (including spaces, `&` and `|`), Niri includes/validation,
Herdr patch checksums, repeat-copy behavior, Git-checkout permission restoration,
and preservation/warnings for an existing target (including destination file
symlinks). Optional tools are used only if already installed; nothing is
installed, authenticated or started in the real home.

`--live-manifest /path/to/private/manifest.json` additionally verifies all captured
files against a pre-reconciliation live snapshot and checks that live files,
chezmoi, system payloads and repo-local `.opencode/` settings remain unchanged.
Snapshots and backups are kept outside this repository.

Do **not** run `install.sh` as a test. Fresh-boot installation, package provisioning,
and real Herdr/Neovim interaction still need a disposable Arch machine or
user-assisted checks. The existing local-entrypoint `lib/00-checks.sh` detection
issue is unchanged; the curl invocation also uses the published branch, not
uncommitted local changes.

## Customization

| Edit              | Location                                         |
| ----------------- | ------------------------------------------------ |
| Packages          | `scripts/03-packages.sh`                         |
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
