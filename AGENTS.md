# eco-linux

- `install.sh` is the repo entrypoint. It `source`s every `scripts/*.sh` in lexicographic order, so ordering is part of the behavior: `00-checks` -> `01-system` -> `02-yay` -> `03-sddm` -> `copy-config` -> `nvidia` -> `packages` -> `zsh` -> `zz-final`.
- This is an Arch installer/config repo, not a normal app package. There is no root CI, test runner, linter, or formatter config.
- Do not use `install.sh` as a casual verification step. It escalates to root, installs packages, enables services, edits `/etc`, and writes into the target user's home.
- Safest repo-level verification for installer changes is syntax-only: `bash -n install.sh scripts/*.sh`.
- `xdg-config/` is the payload copied into the target user's `~/.config` by `scripts/copy-config.sh`. Most user-facing changes belong there.
- `system-config/` holds root-owned files consumed by the installer: NVIDIA env vars and SDDM session/autologin files.
- For Niri, edit `xdg-config/niri/cfg/*.kdl`; `xdg-config/niri/config.kdl` is just an include list.
- `xdg-config/nvim/` has its own local `AGENTS.md`; follow that file for Neovim-specific commands and conventions.
- `xdg-config/opencode/opencode.json` is the config that gets installed into the user environment. `.opencode/opencode.jsonc` only configures OpenCode for this repo workspace.
- Trust the scripts over `README.md`. The README still references non-existent `lib/...` and `configs/...` paths.
- Be careful when testing installer behavior from the repo root: `install.sh` still checks for `lib/00-checks.sh` before deciding whether to download `/tmp/eco-linux`, even though the tracked modules live under `scripts/`.
