-- This will run last in the setup process and is a good place to configure
-- things like custom filetypes. This just pure lua so anything that doesn't
-- fit in the normal config locations above can go here

-- [[ Highlight on yank ]]
-- See `:help vim.highlight.on_yank()`
local eco_group = vim.api.nvim_create_augroup("EcoGroup", { clear = true })
vim.api.nvim_create_autocmd("TextYankPost", {
  callback = function()
    vim.highlight.on_yank()
  end,
  group = eco_group,
  pattern = "*",
})

-- See `:help conceallevel
vim.api.nvim_create_autocmd("FileType", {
  callback = function()
    local ft = vim.bo.filetype
    -- print("ft", ft)
    if ft == "markdown" then
      vim.opt.conceallevel = 1
    else
      vim.opt.conceallevel = 0
    end
  end,
  group = eco_group,
  pattern = { "*" },
})

-- Handle `opencode` events
vim.api.nvim_create_autocmd("User", {
  pattern = "OpencodeEvent:*",
  callback = function(args)
    ---@type opencode.server.Event
    local event = args.data.event

    -- Notify when OpenCode finishes responding
    if event.type == "session.execution.succeeded" then
      vim.notify("`opencode` finished responding")
    end
  end,
  group = eco_group,
})

-- Set colorscheme name for AstroNvim integration
vim.g.colors_name = "dank"

-- NeoTree highlights — linked to standard groups controlled by base16-colorscheme
-- These survive palette changes from external tool regeneration
local hl = vim.api.nvim_set_hl
hl(0, "NeoTreeNormal", { link = "Normal" })
hl(0, "NeoTreeNormalNC", { link = "Normal" })
hl(0, "NeoTreeSignColumn", { link = "SignColumn" })
hl(0, "NeoTreeCursorLine", { link = "CursorLine" })
hl(0, "NeoTreeStatusLine", { link = "StatusLine" })
hl(0, "NeoTreeStatusLineNC", { link = "StatusLineNC" })
hl(0, "NeoTreeVertSplit", { link = "VertSplit" })
hl(0, "NeoTreeWinSeparator", { link = "VertSplit" })
hl(0, "NeoTreeEndOfBuffer", { link = "NonText" })
hl(0, "NeoTreeDirectoryName", { link = "Directory" })
hl(0, "NeoTreeDirectoryIcon", { link = "Directory" })
hl(0, "NeoTreeRootName", { link = "Title" })
hl(0, "NeoTreeDimText", { link = "Comment" })
hl(0, "NeoTreeIndentMarker", { link = "Comment" })
hl(0, "NeoTreeExpander", { link = "Comment" })
hl(0, "NeoTreeGitAdded", { link = "GitGutterAdd" })
hl(0, "NeoTreeGitDeleted", { link = "GitGutterDelete" })
hl(0, "NeoTreeGitModified", { link = "GitGutterChange" })
hl(0, "NeoTreeGitConflict", { link = "Error" })
hl(0, "NeoTreeGitRenamed", { link = "GitGutterChangeDelete" })
hl(0, "NeoTreeGitStaged", { link = "GitGutterAdd" })
hl(0, "NeoTreeGitUnstaged", { link = "Error" })
hl(0, "NeoTreeGitUntracked", { link = "GitGutterChangeDelete" })
hl(0, "NeoTreeGitIgnored", { link = "Comment" })
hl(0, "NeoTreeModified", { link = "WarningMsg" })
hl(0, "NeoTreeFileNameOpened", { link = "String" })
hl(0, "NeoTreeFilterTerm", { link = "Keyword" })
hl(0, "NeoTreeFloatBorder", { link = "FloatBorder" })
hl(0, "NeoTreeFloatNormal", { link = "NormalFloat" })
hl(0, "NeoTreeFloatTitle", { link = "Title" })
hl(0, "NeoTreeTitleBar", { link = "StatusLine" })
hl(0, "NeoTreePreview", { link = "Search" })

-- Heirline mode backgrounds → feeds tier 1 of setup_colors() color resolution
-- These replace the hardcoded fallback colors with dank palette colors
-- hl(0, "HeirlineNormal", { link = "Search" })
-- hl(0, "HeirlineInsert", { link = "Search" })
-- hl(0, "HeirlineVisual", { link = "Search" })
-- hl(0, "HeirlineReplace", { link = "Search" })
-- hl(0, "HeirlineCommand", { link = "Search" })
-- hl(0, "HeirlineTerminal", { link = "Search" })
-- hl(0, "HeirlineInactive", { link = "Search" })
