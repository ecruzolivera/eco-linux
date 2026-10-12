---@type LazySpec
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
-- Use existing opencode sessions from the tmux or Herdr sessionizer.
-- Opencode runs in: tmux → opencode (no nvim terminal layer)
-- V2 discovers the shared background service and targets the latest root
-- session for Neovim's working directory. No --port or embedded terminal.
--
-- Last Updated: 2026-10-11
-- Status: RESOLVED - Using external sessions instead of embedded terminals
-- V1 remote-TUI new-session/scroll mappings are retired: use the OpenCode TUI
-- (Ctrl+X then N; Ctrl+Alt+U / Ctrl+Alt+D) rather than Neovim command calls.
--
return {
  "nickjvandyke/opencode.nvim",
  version = false, -- Stable releases target V1; main supports V2
  branch = "main",
  init = function()
    -- Discover the shared service, but never start an embedded terminal.
    vim.g.opencode_opts = { server = { start = false } }
  end,
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
            opencode_send = function(picker) ---@param picker snacks.Picker
              local opencode = require("opencode")
              local items = vim.tbl_map(function(item)
                return item.file
                  and opencode.format({ path = item.file, from = item.pos, to = item.end_pos })
                  or item.text
              end, picker:selected({ fallback = true }))
              picker:close()
              opencode.ask(table.concat(items, ", ") .. " ")
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
        -- OpenCode runs in an external tmux/Herdr pane, managed separately.
        maps.n[prefix .. "a"] = {
          function()
            opencode.ask("@this: ")
          end,
          desc = "Ask about this",
        }
        maps.n[prefix .. "+"] = {
          function()
            opencode.ask("@buffer ")
          end,
          desc = "Ask with buffer context",
        }
        maps.n[prefix .. "e"] = {
          function()
            opencode.prompt("Explain @this and its context")
          end,
          desc = "Explain this code",
        }
        maps.n[prefix .. "s"] = {
          function()
            opencode.select()
          end,
          desc = "Select prompt",
        }

        -- == Visual Mode Mappings ==
        maps.v[prefix] = { desc = require("astroui").get_icon("OpenCode", 1, true) .. "OpenCode" }
        maps.v[prefix .. "a"] = {
          function()
            opencode.ask("@this: ")
          end,
          desc = "Ask about selection",
        }
        maps.v[prefix .. "+"] = {
          function()
            opencode.ask("@this ")
          end,
          desc = "Ask with selection context",
        }
        maps.v[prefix .. "s"] = {
          function()
            opencode.select()
          end,
          desc = "Select prompt",
        }
      end,
    },
    { "AstroNvim/astroui", opts = { icons = { OpenCode = "" } } },
  },
}
