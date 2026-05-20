--p-@type LazySpec
--
-- OSC 52 CLIPBOARD ISSUE - Historical Documentation
-- =================================================
-- Note: This configuration now uses an existing opencode session running
-- in tmux (started via tmux-sessionizer) instead of an embedded terminal.
-- The OSC 52 issue described below is avoided by not using nvim's terminal.
--
-- HISTORICAL ISSUE (when using embedded terminal):
-- When selecting text with mouse in opencode terminal window, OSC 52
-- escape sequences would leak into the chat input as artifacts.
-- Format: "52;c;<base64-encoded-text>" appeared as raw text in input.
--
-- Environment: ghostty → tmux → nvim terminal → opencode
-- Note: Issue only occurred with nvim terminal, not when running
--       opencode directly in tmux (opencode → tmux → ghostty works fine)
--
-- Attempted Fixes (all unsuccessful with embedded terminal):
-- 1. ghostty: clipboard-write = deny (prevents OSC 52 from ghostty)
-- 2. tmux: set -s set-clipboard off (disables tmux OSC 52 handling)
-- 3. nvim: Set g:clipboard to use wl-clipboard instead of OSC 52 provider
--
-- Current Solution:
-- Use existing opencode session from tmux-sessionizer.
-- Opencode runs in: tmux → opencode (no nvim terminal layer)
-- Nvim connects to the existing session via opencode.nvim auto-detection.
--
-- Last Updated: 2026-03-20
-- Status: RESOLVED - Using tmux session instead of embedded terminal
--
return {
  "nickjvandyke/opencode.nvim",
  version = "*", -- Latest stable release
  dependencies = {
    {
      -- `snacks.nvim` integration is recommended, but optional
      ---@module "snacks" <- Loads `snacks.nvim` types for configuration intellisense
      "folke/snacks.nvim",
      optional = true,
      opts = {
        input = {}, -- Enhances `ask()`
        picker = { -- Enhances `select()`
          actions = {
            opencode_send = function(...)
              return require("opencode").snacks_picker_send(...)
            end,
          },
          win = {
            input = {
              keys = {
                ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
              },
            },
          },
        },
      },
    },
  },
  specs = {
    {
      "AstroNvim/astrocore",
      ---@param opts AstroCoreOpts
      opts = function(_, opts)
        local opencode = require("opencode")
        local maps = assert(opts.mappings)
        local prefix = "<Leader>a"

        -- == Normal Mode Mappings ==
        maps.n[prefix] = { desc = require("astroui").get_icon("OpenCode", 1, true) .. "OpenCode" }
        -- Note: Toggle mapping removed - opencode runs in tmux session managed separately
        maps.n[prefix .. "a"] = {
          function()
            opencode.ask("@this: ", { submit = true })
          end,
          desc = "Ask about this",
        }
        maps.n[prefix .. "+"] = {
          function()
            opencode.prompt("@buffer", { append = true })
          end,
          desc = "Add buffer to prompt",
        }
        maps.n[prefix .. "e"] = {
          function()
            opencode.prompt("Explain @this and its context", { submit = true })
          end,
          desc = "Explain this code",
        }
        maps.n[prefix .. "n"] = {
          function()
            opencode.command("session_new")
          end,
          desc = "New session",
        }
        maps.n[prefix .. "s"] = {
          function()
            opencode.select()
          end,
          desc = "Select prompt",
        }
        maps.n["<S-C-u>"] = {
          function()
            opencode.command("messages_half_page_up")
          end,
          desc = "Messages half page up",
        }
        maps.n["<S-C-d>"] = {
          function()
            opencode.command("messages_half_page_down")
          end,
          desc = "Messages half page down",
        }

        -- == Visual Mode Mappings ==
        maps.v[prefix] = { desc = require("astroui").get_icon("OpenCode", 1, true) .. "OpenCode" }
        maps.v[prefix .. "a"] = {
          function()
            opencode.ask("@this: ", { submit = true })
          end,
          desc = "Ask about selection",
        }
        maps.v[prefix .. "+"] = {
          function()
            opencode.prompt("@this")
          end,
          desc = "Add selection to prompt",
        }
        maps.v[prefix .. "s"] = {
          function()
            opencode.select()
          end,
          desc = "Select prompt",
        }

        -- Use existing opencode session from tmux (auto-detect, no server config needed)
        vim.g.opencode_opts = {}
      end,
    },
    { "AstroNvim/astroui", opts = { icons = { OpenCode = "" } } },
  },
}
