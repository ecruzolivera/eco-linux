-- AstroLSP allows you to customize the features in AstroNvim's LSP configuration engine
-- Configuration documentation can be found with `:h astrolsp`
local Snacks = require("snacks")
---@type LazySpec
return {
  "AstroNvim/astrolsp",
  ---@type AstroLSPOpts
  opts = {
    -- Configuration table of features provided by AstroLSP
    features = {
      codelens = true,        -- enable/disable codelens refresh on start
      inlay_hints = false,    -- enable/disable inlay hints on start
      semantic_tokens = true, -- enable/disable semantic token highlighting
    },
    -- customize lsp formatting options
    formatting = {
      -- control auto formatting on save
      format_on_save = {
        enabled = true,     -- enable or disable format on save globally
        allow_filetypes = { -- enable format on save for specified filetypes only
          -- "go",
        },
        ignore_filetypes = { -- disable format on save for specified filetypes
          -- "python",
        },
      },
      disabled = { -- disable formatting capabilities for the listed language servers
        -- disable lua_ls formatting capability if you want to use StyLua to format your lua code
        -- "lua_ls",
      },
      timeout_ms = 1000, -- default format timeout
      -- filter = function(client) -- fully override the default formatting function
      --   return true
      -- end
    },
    -- enable servers that you already have installed without mason
    servers = {
      -- "pyright"
    },
    -- customize language server configuration passed to `vim.lsp.config`
    -- client specific configuration can also go in `lsp/` in your configuration root (see `:h lsp-config`)
    config = {
      clangd = { capabilities = { offsetEncoding = "utf-8" } },
      ltex = {
        settings = {
          ltex = {
            -- language = "auto",
            language = "auto",
            checkFrequency = "save",
            additionalRules = {
              motherTongue = "es",
            },
            dictionary = (function()
              -- local function dump_to_string(o)
              --   if type(o) == "table" then
              --     local s = "{ "
              --     for k, v in pairs(o) do
              --       if type(k) ~= "number" then
              --         k = '"' .. k .. '"'
              --       end
              --       s = s .. "[" .. k .. "] = " .. dump_to_string(v) .. ","
              --     end
              --     return s .. "} "
              --   else
              --     return tostring(o)
              --   end
              -- end

              local words = {}
              local custom_dic_file = vim.fn.expand("$HOME/.config/spell.eco/en.utf-8.add")
              for word in io.open(custom_dic_file, "r"):lines() do
                table.insert(words, word)
              end
              local dics = {
                ["en"] = words,
                ["en-US"] = words,
                ["es"] = words,
                ["es-ES"] = words,
                ["es-MX"] = words,
              }
              return dics
            end)(),
          },
        },
      },
    },
    -- customize how language servers are attached
    handlers = {
      -- a function with the key `*` modifies the default handler, functions takes the server name as the parameter
      -- ["*"] = function(server) vim.lsp.enable(server) end

      -- the key is the server that is being setup with `vim.lsp.config`
      -- rust_analyzer = false, -- setting a handler to false will disable the set up of that language server
    },
    -- Configure buffer local auto commands to add when attaching a language server
    autocmds = {
      -- first key is the `augroup` to add the auto commands to (:h augroup)
      lsp_codelens_refresh = {
        -- Optional condition to create/delete auto command group
        -- can either be a string of a client capability or a function of `fun(client, bufnr): boolean`
        -- condition will be resolved for each client on each execution and if it ever fails for all clients,
        -- the auto commands will be deleted for that buffer
        cond = "textDocument/codeLens",
        -- cond = function(client, bufnr) return client.name == "lua_ls" end,
        -- list of auto commands to set
        {
          -- events to trigger
          event = { "InsertLeave", "BufEnter" },
          -- the rest of the autocmd options (:h nvim_create_autocmd)
          desc = "Refresh codelens (buffer)",
          callback = function(args)
            if require("astrolsp").config.features.codelens then
              vim.lsp.codelens.enable(true, { bufnr = args.buf })
            end
          end,
        },
      },
    },
    -- mappings to be set up on attaching of a language server
    mappings = {
      n = {
        ["<Leader>uY"] = {
          function()
            require("astrolsp.toggles").buffer_semantic_tokens()
          end,
          desc = "Toggle LSP semantic highlight (buffer)",
          cond = function(client)
            return client:supports_method("textDocument/semanticTokens/full")
                and vim.lsp.semantic_tokens ~= nil
          end,
        },
        gra = false,
        grn = false,
        grr = false,
        gri = false,

        gD = { Snacks.picker.lsp_declarations, desc = "Goto Declaration" },
        -- gD = { vim.lsp.buf.declaration, desc = "Declaration of current symbol" },
        gI = { Snacks.picker.lsp_implementations, desc = "Goto Implementation" },
        -- gI = { vim.lsp.buf.implementation, desc = "Goto Implementation" },
        gd = { vim.lsp.buf.definition, desc = "Goto Definition" },
        gk = { vim.lsp.buf.hover, desc = "Show Help" },
        gr = { Snacks.picker.lsp_references, desc = "Show References" },
        -- gr = { vim.lsp.buf.references, desc = "Show References" },
        gy = { Snacks.picker.lsp_type_definitions, desc = "Goto T[y]pe Definition" },
        -- gy = { vim.lsp.buf.type_definition, desc = "Goto T[y]pe Definition" },
        ["<leader>lr"] = { vim.lsp.buf.rename, desc = "Rename" },
        ["<leader>la"] = { vim.lsp.buf.code_action, desc = "Code Action" },
      },
    },
  },
}
