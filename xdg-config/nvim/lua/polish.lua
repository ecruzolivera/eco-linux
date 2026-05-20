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
    ---@type opencode.cli.client.Event
    local event = args.data.event

    -- Notify when OpenCode finishes responding
    if event.type == "session.idle" then
      vim.notify("`opencode` finished responding")
    end
  end,
  group = eco_group,
})
