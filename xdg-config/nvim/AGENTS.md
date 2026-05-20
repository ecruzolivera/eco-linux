# AstroNvim Configuration - Agent Guidelines

This is an AstroNvim v5+ configuration written in Lua. This guide provides essential information for AI coding agents working in this repository.

## Project Overview

- **Type**: Neovim configuration (based on AstroNvim framework)
- **Language**: Lua
- **Framework**: AstroNvim v5+
- **Plugin Manager**: lazy.nvim
- **Structure**: Modular plugin-based configuration

## Directory Structure

```
.
├── init.lua                 # Entry point (bootstraps lazy.nvim)
├── lua/
│   ├── lazy_setup.lua      # Lazy.nvim configuration
│   ├── polish.lua          # Final polish/custom settings
│   ├── community.lua       # Community plugin imports
│   └── plugins/            # Plugin configurations
│       ├── astrocore.lua   # Core settings, mappings, options
│       ├── astrolsp.lua    # LSP configuration
│       ├── astroui.lua     # UI configuration
│       ├── mason.lua       # LSP/tool installer config
│       ├── none-ls.lua     # Linting/formatting
│       ├── treesitter.lua  # Syntax highlighting
│       ├── copilot.lua     # AI completion
│       └── user.lua        # User-specific plugins
├── .stylua.toml            # Lua formatter configuration
└── selene.toml             # Lua linter configuration
```

## Build/Lint/Test Commands

### Formatting

```bash
# Format all Lua files with StyLua
stylua .

# Format specific file
stylua lua/plugins/astrolsp.lua

# Check formatting without modifying
stylua --check .
```

### Linting

```bash
# Lint with Selene
selene lua/

# Lint specific file
selene lua/plugins/astrolsp.lua
```

### No Traditional Tests

This is a configuration repository without a test suite. Validation happens through:

- Running Neovim: `nvim`
- Checking for errors in `:messages`
- Using `:checkhealth` for diagnostics

### Plugin Management

```bash
# Update plugins (run inside Neovim)
:Lazy update

# Check plugin status
:Lazy

# Clean unused plugins
:Lazy clean
```

## Code Style Guidelines

### Formatting Rules (.stylua.toml)

- **Indentation**: 2 spaces
- **Column width**: 100 characters
- **Line endings**: Unix (LF)
- **Quote style**: Auto-prefer double quotes
- **Call parentheses**: None (omit parentheses when possible)
- **Simple statements**: Always collapse to single line

### Lua Conventions

#### 1. Type Annotations

Use EmmyLua annotations for better LSP support:

```lua
---@type LazySpec
return {
  "plugin/name",
  ---@type PluginOpts
  opts = {},
}

---@param client lsp.Client
---@param bufnr number
local function on_attach(client, bufnr)
  -- implementation
end
```

#### 2. Naming Conventions

- **Variables**: `snake_case` (e.g., `custom_dic_file`, `eco_group`)
- **Functions**: `snake_case` (e.g., `dump_to_string()`)
- **Constants**: `UPPER_CASE` or `snake_case`
- **Tables/configs**: `snake_case`

#### 3. Plugin Structure

Each plugin file should return a LazySpec table:

```lua
---@type LazySpec
return {
  "author/plugin-name",
  event = "VeryLazy", -- or cmd, ft, keys, etc.
  dependencies = { "other/plugin" },
  ---@type PluginOpts
  opts = {
    -- plugin options
  },
  config = function(_, opts)
    -- custom setup logic if needed
  end,
}
```

#### 4. Imports and Requires

- Use `require` without parentheses when possible: `require "module"`
- With parentheses when assigning: `local mod = require("module")`
- Defer loading with lazy loading events (event, cmd, ft, keys)

#### 5. Comments

- Use `--` for single-line comments
- Use `---` for documentation comments (EmmyLua)
- Group related settings with section comments:

```lua
-- == LSP Configuration ==

-- == Mappings ==
```

#### 6. Tables and Options

- Use trailing commas in multi-line tables
- Align similar option groups vertically when it improves readability

```lua
opts = {
  format_on_save = true,
  timeout_ms = 1000,
  features = {
    codelens = true,
    inlay_hints = false,
  },
}
```

#### 7. Function Definitions

Prefer local functions for helpers:

```lua
local function setup_keymaps()
  -- implementation
end
```

Use inline functions for callbacks:

```lua
callback = function() vim.highlight.on_yank() end
```

#### 8. String Handling

- Prefer double quotes: `"string"`
- Use single quotes in nested strings or format strings
- Use `..` for concatenation
- Use `string.format()` or `("%s"):format()` for complex strings

#### 9. Conditionals and Control Flow

- Use early returns to reduce nesting
- Prefer ternary-style for simple conditions:

```lua
local value = condition and true_value or false_value
```

#### 10. Error Handling

- Use `pcall()` for operations that might fail:

```lua
if not pcall(require, "lazy") then
  vim.api.nvim_echo({ { "Error loading lazy", "ErrorMsg" } }, true, {})
  return
end
```

### Vim API Usage

- Prefer `vim.opt` over `vim.o` for options
- Use `vim.api.nvim_*` for low-level API calls
- Use `vim.fn` for Vimscript functions
- Use `(vim.uv or vim.loop)` for backwards compatibility with older Neovim versions

## Common Patterns

### Auto Commands

```lua
local group = vim.api.nvim_create_augroup("GroupName", { clear = true })
vim.api.nvim_create_autocmd("Event", {
  callback = function() -- code end,
  group = group,
  pattern = "*",
})
```

### Key Mappings (in astrocore.lua)

```lua
mappings = {
  n = { -- normal mode
    ["<Leader>x"] = { "<cmd>Command<cr>", desc = "Description" },
    ["<C-s>"] = { ":w!<cr>", desc = "Save File" },
  },
}
```

### LSP Configuration (in astrolsp.lua)

```lua
config = {
  server_name = {
    settings = {
      -- server-specific settings
    },
  },
}
```

## Important Files

- **init.lua**: Entry point, do NOT modify unless necessary (marked with warning comment)
- **lua/lazy_setup.lua**: Configure lazy.nvim and AstroNvim options
- **lua/plugins/astrocore.lua**: Core vim options, mappings, and autocommands
- **lua/plugins/astrolsp.lua**: All LSP-related configuration
- **lua/polish.lua**: Final polish, custom filetypes, and late-loading autocommands

## Best Practices

1. **Plugin Configuration**: Always add new plugins in `lua/plugins/` directory as separate files
2. **Keymaps**: Define in `astrocore.lua` under `mappings`
3. **LSP Settings**: Add to `astrolsp.lua` under appropriate section
4. **Lazy Loading**: Use appropriate lazy.nvim events (`event`, `ft`, `cmd`, `keys`)
5. **Performance**: Defer loading with events when possible
6. **Documentation**: Use EmmyLua annotations for type hints
7. **Compatibility**: Use `(vim.uv or vim.loop)` for older Neovim support
8. **Comments**: Mark sections with `-- ==` for major configuration blocks
9. **Formatting**: Always run `stylua .` before committing
10. **Testing**: Launch `nvim` and check `:messages` and `:checkhealth` after changes

## Disabled Features

- Global format.enable is disabled (see `.luarc.json`)
- Certain default plugins are disabled in lazy_setup.lua (gzip, netrw, tar, etc.)
- Format on save can be controlled per-filetype in astrolsp.lua

## Notes for Agents

- This configuration uses AstroNvim v5+ conventions
- Plugin specs follow lazy.nvim format
- The main entry point (init.lua) should rarely be modified
- Most customization happens in `lua/plugins/` files
- LSP servers are managed through Mason (configured in mason.lua)
- Format-on-save is enabled globally but can be customized per filetype
