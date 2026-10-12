---@type LazySpec
return {
  "selimacerbas/markdown-preview.nvim",
  dependencies = { "selimacerbas/live-server.nvim" },
  config = function()
    require("markdown_preview").setup({
      -- all optional; sane defaults shown
      instance_mode = "takeover", -- "takeover" (one tab) or "multi" (tab per instance)
      port = 0, -- 0 = auto (8421 for takeover, OS-assigned for multi)
      open_browser = true,
      default_theme = "dark", -- "dark" or "light"; initial preview theme
      debounce_ms = 300,
      mermaid_renderer = "rust",
    })
  end,
  specs = {
    {
      "AstroNvim/astrocore",
      ---@param opts AstroCoreOpts
      opts = function(_, opts)
        local maps = assert(opts.mappings)
        local prefix = "<Leader>mp"
        maps.n[prefix] = { desc = require("astroui").get_icon("MarkdownPreview", 1, true) .. "Markdown Preview" }
        maps.n[prefix .. "s"] = { "<cmd>MarkdownPreview<cr>", desc = "Start preview" }
        maps.n[prefix .. "S"] = { "<cmd>MarkdownPreviewStop<cr>", desc = "Stop preview" }
        maps.n[prefix .. "r"] = { "<cmd>MarkdownPreviewRefresh<cr>", desc = "Refresh preview" }
      end,
    },
  },
}
