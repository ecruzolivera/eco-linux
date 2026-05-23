# eco-linux

- `install.sh` is the repo entrypoint. It `source`s every `scripts/*.sh` in lexicographic order, so ordering is part of the behavior: `00-checks` -> `01-system` -> `02-yay` -> `03-packages` -> `04-sddm` -> `05-nvidia` -> `06-zsh` -> `07-copy-config` -> `09-docker` -> `10-firewall` -> `zz-final`.
- This is an Arch installer/config repo, not a normal app package. There is no root CI, test runner, linter, or formatter config.
- Do not use `install.sh` as a casual verification step. It escalates to root, installs packages, enables services, edits `/etc`, and writes into the target user's home.
- Safest repo-level verification for installer changes is syntax-only: `bash -n install.sh scripts/*.sh`.
- `xdg-config/` is copied into `~/.config` by `scripts/07-copy-config.sh`. Most user-facing changes belong there.
- `home-root-config/` is copied into `~/` (`.zshrc`, `.profile`, `.bashrc`, `.vimrc`, etc.) by `scripts/07-copy-config.sh`.
- `local-bin/` is copied into `~/.local/bin/` by `scripts/07-copy-config.sh`.
- `system-config/` holds root-owned files consumed by the installer: NVIDIA env vars and SDDM session/autologin files.
- For Niri, edit `xdg-config/niri/cfg/*.kdl`; `xdg-config/niri/config.kdl` is just an include list.
- `xdg-config/nvim/` has its own local `AGENTS.md`; follow that file for Neovim-specific commands and conventions.
- `xdg-config/opencode/opencode.json` is the config that gets installed into the user environment. `.opencode/opencode.jsonc` only configures OpenCode for this repo workspace.
- Be careful when testing installer behavior from the repo root: `install.sh` still checks for `lib/00-checks.sh` before deciding whether to download `/tmp/eco-linux`, even though the actual modules live under `scripts/`.
- Personal dotfiles are managed via `home-root-config/` in this repo. chezmoi is installed and configured (`~/.config/chezmoi/chezmoi.toml`) for users who want to layer personal dotfiles on top.
- `03-packages.sh` temporarily creates `/etc/sudoers.d/99-eco-nopasswd` for AUR builds; `zz-final.sh` removes it.
