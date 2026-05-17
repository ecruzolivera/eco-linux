# eco-linux

Arch Linux customization — Niri + Noctalia Shell + your apps.

## Usage

```bash
curl -fsSL https://raw.githubusercontent.com/<your-username>/eco-linux/main/install.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/<your-username>/eco-linux.git
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
| **CLI tools**      | gh, glab, neovim                 |
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

Your own configs go in:

- `~/.config/ghostty/config` — ghostty (bring your own)
- `~/.config/nvim/` — neovim (bring your own)
- `~/.config/niri/config.kdl` — niri (provided)
- `~/.config/yazi/yazi.toml` — yazi (provided)
- `~/.config/noctalia/` — noctalia settings (managed via shell UI)

## Customization

Edit package lists in `lib/03-packages-official.sh` and `lib/04-packages-aur.sh`. Edit the niri config in `configs/niri/config.kdl`.
