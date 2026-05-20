local Snacks = require("snacks")
return {
  "ecruzolivera/snacks-unicode",
  dependencies = { "folke/snacks.nvim" },
  config = function(_, opts)
    require("snacks-unicode").setup(opts)
  end,
  event = "VeryLazy",
  keys = {
    {
      "<leader>fu",
      function()
        Snacks.picker.pick("unicode")
      end,
      desc = "Unicode Symbols",
    },
    {
      "<leader>fU",
      function()
        Snacks.picker.pick("unicode", { categories = { "emoji" } })
      end,
      desc = "Emoji",
    },
  },
}
