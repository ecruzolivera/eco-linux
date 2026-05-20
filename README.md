# eco-linux

Arch Linux customization — Niri + Noctalia Shell + your apps.

## Prerequisites: Installing Arch Linux

Before running eco-linux, you need a minimal Arch Linux installation. Follow the [Omarchy manual installation guide](https://learn.omacom.io/2/the-omarchy-manual/96/manual-installation) for detailed steps.

Quick overview of the `archinstall` options required:

| Section                      | Option                                                      |
| ---------------------------- | ----------------------------------------------------------- |
| **Mirrors and repositories** | Select your country                                         |
| **Disk configuration**       | Default partitioning layout, btrfs (compression: yes)       |
| **Disk encryption**          | LUKS + encryption password + select partition (recommended) |
| **Bootloader**               | Limine                                                      |
| **Authentication**           | Set a root password, add a user with Superuser (sudo)       |
| **Audio**                    | pipewire                                                    |
| **Network configuration**    | Copy ISO network config                                     |
| **Timezone**                 | Set yours                                                   |

Once the installation completes, reboot, login as your user, and run eco-linux.

> **Note:** Disk encryption is recommended but not strictly required for eco-linux. Without encryption, you can skip that step in `archinstall`.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/ecruzolivera/eco-linux/master/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/ecruzolivera/eco-linux.git
cd eco-linux
sudo bash install.sh
```

## What it installs

| Category           | Software                         |
| ------------------ | -------------------------------- |
| **WM / Shell**     | niri, Noctalia Shell             |
| **Terminal**       | ghostty                          |
| **Browsers**       | Firefox Developer Edition, Brave |
| **File managers**  | yazi (TUI), nautilus (GUI)       |
| **CLI tools**      | gh, glab, neovim, chezmoi        |
| **Media / Gaming** | mpv, steam                       |
| **Other**          | Bitwarden, LocalSend             |

## NVIDIA

If an NVIDIA GPU is detected, the script installs `nvidia-dkms`, `nvidia-utils`, `nvidia-settings`, `egl-wayland`, and sets Wayland environment variables in `/etc/environment`.

## Noctalia Shell

Noctalia runs on top of niri as a desktop shell (bar, launcher, notifications, lock screen, OSD). The polkit-agent plugin is pre-configured and auto-installs on first launch.

## Requirements

- Arch Linux (fresh install recommended)
- `sudo` configured for your user
- Internet connection

## Configuration

Personal dotfiles are managed by [chezmoi](https://chezmoi.io) from
[github.com/ecruzolivera/dotfiles](https://github.com/ecruzolivera/dotfiles).
The installer bootstraps chezmoi on first run and applies your personal configs
on top of the eco-linux defaults.

Configs owned by eco-linux (base desktop defaults):
- `~/.config/niri/config.kdl` — niri
- `~/.config/noctalia/` — noctalia settings (managed via shell UI)

Personal configs managed by chezmoi (bring your own):
- `~/.config/ghostty/config` — ghostty
- `~/.config/nvim/` — neovim
- `~/.config/yazi/` — yazi
- `~/.config/git/config` — git
- `~/.config/tmux/tmux.conf` — tmux
- everything else in `~/.config/`

## Customization

- **Packages**: edit `scripts/packages.sh`
- **Niri**: edit `xdg-config/niri/cfg/*.kdl`
- **Personal dotfiles**: edit your [dotfiles repo](https://github.com/ecruzolivera/dotfiles)
