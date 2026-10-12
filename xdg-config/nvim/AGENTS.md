# AstroNvim v6 Configuration — Agent Guide

Neovim config based on **AstroNvim v6** (`lazy_setup.lua` pins `version = "^6"`), managed via lazy.nvim.

## Directory Structure

```
.
├── init.lua            # Entry point (bootstraps lazy.nvim). DO NOT EDIT unless necessary.
├── selene.toml         # Lua linter config (neovim std, permissive rules)
├── lua/
│   ├── lazy_setup.lua  # Lazy.nvim setup, AstroNvim import, disabled_plugins
│   ├── polish.lua      # Final polish: yank highlight, conceal, opencode events, neo-tree highlights, dank colors
│   ├── community.lua   # AstroCommunity packs (bash, docker, eslint, lua, python, rust, ts, etc.)
│   └── plugins/        # Plugin configurations
│       ├── astrocore.lua   # vim options, mappings, autocommands
│       ├── astrolsp.lua    # LSP server settings
│       ├── astroui.lua     # UI / Heirline statusline
│       ├── cmp_ai.lua      # AI completion (supermaven via blink.cmp)
│       ├── copilot.lua     # Copilot chat
│       ├── dankcolors.lua  # Custom "dank" colorscheme
│       ├── mason.lua       # LSP/tool installer
│       ├── neo-tree.lua    # File explorer
│       ├── none-ls.lua     # Linting/formatting via null-ls
│       ├── obsidian.lua    # Obsidian vault integration
│       ├── opencode.lua    # OpenCode AI assistant plugin
│       ├── snacks-unicode.lua  # Unicode / emoji picker
│       ├── toggleterm.lua  # Terminal toggle
│       ├── treesitter.lua  # Syntax highlighting, indent, folds
│       └── user.lua        # User-specific plugins
```

## Key Conventions

- **Mappings**: Define in `astrocore.lua` under `mappings` (mode-keyed tables). Use `desc` on every entry.
- **LSP settings**: Add to `astrolsp.lua` under the `config` table keyed by server name.
- **New plugins**: Create separate files in `lua/plugins/`, each returning a `LazySpec` table.
- **Colorscheme**: Custom "dank" colorscheme set via `polish.lua:47` (`vim.g.colors_name = "dank"`).
- **Neo-tree highlights**: Linked to standard groups in `polish.lua` — survives external palette changes.
- **Snacks**: AstroNvim's Snacks.nvim integration (used for picker in astrocore.lua).

## Tools & Commands

```bash
# Format with StyLua (only if installed)
stylua lua/

# Lint with Selene (only if installed)
selene lua/

# Validate — launch nvim and check :messages, :checkhealth
```

No formatter/linter config files exist in repo (`.stylua.toml` was removed). StyLua defaults apply if used.

## Testing

No test suite. Validate by running `nvim` and checking `:messages` and `:checkhealth`.

## Plugin Management (inside Neovim)

```
:Lazy        — status
:Lazy update — update plugins
:Lazy clean  — remove unused
```

## Style Rules (verified across actual files)

- Indent: 2 spaces, no tabs
- Quote style: double by convention
- `require` calls: parentheses omitted when standalone (`require "mod"`), kept for assignment (`local x = require("mod")`)
- Trailing commas in multi-line tables
- LazySpec event keys: `event`, `cmd`, `ft`, `keys`
- EmmyLua annotations (`---@type`, `---@param`, `---@return`)
- snake_case for variables and functions

## Notes

- Not a git repository — no commits, branches, or CI.
- AstroNvim defaults from v6 are imported; this config only overrides/customizes specific behavior.
- AstroCommunity packs (in `community.lua`) provide per-language LSP configs — commented lines indicate available opt-in packs.
