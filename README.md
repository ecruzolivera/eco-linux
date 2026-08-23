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
| **Terminal**     | ghostty, alacritty, tmux, zsh + oh-my-zsh                                                                       |
| **Browsers**     | Firefox Developer Edition, Brave, Chromium                                                                      |
| **Editor**       | neovim (full config)                                                                                            |
| **Dev tools**    | gh, glab, docker (+ buildx, compose), chezmoi, mise, just, mise, clang/llvm, gdb, lldb, git-lfs, ruby, luarocks |
| **CLI utils**    | bat, eza, fd, fzf, ripgrep, jq, zoxide, tldr, fastfetch, diff-so-fancy, lazygit                                 |
| **Files**        | yazi, nautilus, gparted, gnome-disk-utility, evince                                                             |
| **Media**        | mpv, imv, gimp, imagemagick, cava, ffmpegthumbnailer                                                            |
| **Recording**    | wf-recorder, grim, satty                                                                                        |
| **Gaming**       | steam, qbittorrent                                                                                              |
| **Network**      | NetworkManager, iwd, wl-clipboard, wiremix, socat                                                               |
| **Security**     | UFW (default-deny), systemd-resolved (DNS-over-TLS), gnome-keyring, fprintd                                     |
| **System**       | SDDM (auto-login), pipewire/wireplumber, power-profiles-daemon, cups, brightnessctl, playerctl, bluetui         |
| **Fonts**        | Noto (full/CJK/emoji), FiraCode Nerd, JetBrains Mono Nerd, Font Awesome                                         |
| **Theming**      | adwaita-cursors, gnome-themes-extra, yaru-icon-theme, qt6ct, matugen                                            |
| **AUR**          | brave-bin, localsend-bin, megasync-bin, riskie-bin, worktrunk-bin, limine-snapper-sync                          |
| **User scripts** | `eco-screenrecording`, `eco-format-usb`, `eco-delink`, `tmux-sessionizer` (`~/.local/bin/`)                     |

## How it works

The installer sources `scripts/*.sh` in lexicographic order:

```
00-checks → 01-system → 02-yay → 03-packages → 04-sddm → 05-nvidia → 06-zsh → 07-copy-config → 08-battery → 09-docker → 10-firewall → zz-final
```

Configs are organized into payload directories:

| Directory           | Copies to              | Contents                                                                                                        |
| ------------------- | ---------------------- | --------------------------------------------------------------------------------------------------------------- |
| `xdg-config/`       | `~/.config/`           | niri, DankMaterialShell, nvim, ghostty, git, tmux, yazi, bat, bottom, chezmoi, mise, opencode, zathura, etc.    |
| `home-root-config/` | `~/`                   | `.zshrc`, `.profile`, `.bashrc`, `.vimrc`, `.Xresources`, `.zshenv`, `.editorconfig`, `.ideavimrc`, `.xprofile` |
| `local-bin/`        | `~/.local/bin/`        | `eco-autostart.sh`, `eco-delink.sh`, `eco-format-usb.sh`, `eco-screenrecording.sh`, `tmux-sessionizer`          |
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

## Customization

| Edit              | Location                                         |
| ----------------- | ------------------------------------------------ |
| Packages          | `scripts/03-packages.sh`                         |
| Niri              | `xdg-config/niri/*.kdl`                          |
| Home dotfiles     | `home-root-config/`                              |
| User scripts      | `local-bin/`                                     |
| Docker setup      | `scripts/09-docker.sh`                           |
| Firewall rules    | `scripts/10-firewall.sh`                         |
| System configs    | `system-config/` (NVIDIA, SDDM)                  |
| XDG configs       | `xdg-config/` (neovim, ghostty, git, tmux, etc.) |
| Personal dotfiles | chezmoi repo + `~/` dotfiles                     |
