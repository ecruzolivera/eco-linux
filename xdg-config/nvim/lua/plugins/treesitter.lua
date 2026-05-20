-- Customize Treesitter
--
-- Customize Treesitter
-- --------------------
-- Treesitter customizations are handled with AstroCore
-- as nvim-treesitter simply provides a download utility for parsers

---@type LazySpec
return {
  "AstroNvim/astrocore",
  ---@type AstroCoreOpts
  opts = {
    treesitter = {
      highlight = true, -- enable/disable treesitter based highlighting
      indent = true, -- enable/disable treesitter based indentation
      auto_install = true, -- enable/disable automatic installation of detected languages
      ensure_installed = {
        "astro",
        "bash",
        "c",
        "cmake",
        "cpp",
        "css",
        "dockerfile",
        "go",
        "html",
        "javascript",
        "jsdoc",
        "json",
        "kdl",
        --"kotlin",
        "lua",
        "make",
        "python",
        "qmldir",
        "qmljs",
        "rust",
        "slint",
        "tsx",
        "typescript",
        "vim",
        "xml",
        "yaml",
      },
    },
  },
}
