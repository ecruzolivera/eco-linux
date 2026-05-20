---@type LazySpec
-- Configure toggleterm.nvim floating terminal size
-- This affects <Leader>gg (lazygit) and other floating terminals
return {
  "akinsho/toggleterm.nvim",
  opts = {
    float_opts = {
      border = "rounded",
      width = function()
        return math.floor(vim.o.columns * 0.95)
      end,
      height = function()
        return math.floor(vim.o.lines * 0.90)
      end,
    },
  },
}
