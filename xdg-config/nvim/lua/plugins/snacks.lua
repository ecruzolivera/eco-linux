-- Snacks image support for SVG: picker previews, `:e file.svg` renders,
-- and `:SvgText` / `:SvgImages` to edit SVGs as text instead.

---@type LazySpec
return {
  "folke/snacks.nvim",
  config = function(_, opts)
    -- `svg` is missing from snacks' default `image.formats`. The whole list
    -- must be set: list-like opts values are replaced, not merged. Injected
    -- before setup so snacks' lazy-loader one-shot (snacks/init.lua:196)
    -- also covers `*.svg`, making the first `.svg` open after startup attach
    -- deterministically (a BufReadCmd present before the read suppresses
    -- BufReadPre, so the loader cannot win the race).
    opts.image = opts.image or {}
    local formats = vim.deepcopy(opts.image.formats or Snacks.config.image.formats)
    if not vim.tbl_contains(formats, "svg") then
      formats[#formats + 1] = "svg"
    end
    opts.image.formats = formats
    require("snacks").setup(opts)

    local group = vim.api.nvim_create_augroup("snacks_svg", { clear = true })
    local svg_enabled = true -- whether `.svg` buffers open as images
    local per_format = {} ---@type table<string, function>
    local one_shot = {} ---@type {id?: number, callback?: function, once?: boolean}
    local applied ---@type boolean?

    -- Rebuild snacks' image read hooks with or without `*.svg`. Surgery
    -- because nvim 0.12 `nvim_del_autocmd` takes only an id and all patterns
    -- of one autocmd share that id. `nvim_get_autocmds` errors on unknown
    -- groups (the image module sets itself up lazily), hence the pcalls.
    local function sync()
      local patterns = vim.tbl_map(function(f)
        return "*." .. f
      end, Snacks.config.image.formats)
      local without_svg = vim.tbl_filter(function(p)
        return p ~= "*.svg"
      end, patterns)

      -- capture the per-format callbacks once the image module is up
      local ok, aus = pcall(vim.api.nvim_get_autocmds, { group = "snacks.image" })
      if ok then
        for _, au in ipairs(aus) do
          if au.event == "BufReadCmd" or au.event == "BufWriteCmd" then
            per_format[au.event] = au.callback
          end
        end
      end

      -- the lazy-loader one-shot (group "snacks") matches image formats too;
      -- remove it when off so svg reads fall back to text, restore when on
      -- (but only while the image module is not up yet, to avoid resurrecting
      -- a one-shot that already fired)
      ok, aus = pcall(vim.api.nvim_get_autocmds, { group = "snacks", event = "BufReadCmd" })
      if ok then
        local id, callback, once
        for _, au in ipairs(aus) do
          if au.pattern == "*.svg" or vim.tbl_contains(without_svg, au.pattern) then
            id, callback, once = au.id, au.callback, au.once
          end
        end
        if svg_enabled then
          if one_shot.id and not id and not per_format.BufReadCmd then
            vim.api.nvim_create_autocmd("BufReadCmd", {
              group = "snacks",
              pattern = patterns,
              once = one_shot.once ~= false,
              callback = one_shot.callback,
            })
          end
        elseif id then
          one_shot = { id = id, callback = callback, once = once }
          pcall(vim.api.nvim_del_autocmd, id)
        end
      end

      if per_format.BufReadCmd and per_format.BufWriteCmd and applied ~= svg_enabled then
        for _, event in ipairs { "BufReadCmd", "BufWriteCmd" } do
          vim.api.nvim_clear_autocmds { group = "snacks.image", event = event }
          vim.api.nvim_create_autocmd(event, {
            group = "snacks.image",
            pattern = svg_enabled and patterns or without_svg,
            callback = per_format[event],
          })
        end
        applied = svg_enabled
      end
    end

    -- registered after snacks' own BufReadPre loader (snacks/init.lua:186),
    -- so it runs right after the image module (re)creates its hooks and
    -- keeps them in sync with the toggle
    vim.api.nvim_create_autocmd("BufReadPre", {
      group = group,
      nested = true,
      callback = sync,
    })

    vim.api.nvim_create_user_command("SvgText", function(cmd)
      local path = cmd.args ~= "" and vim.fn.fnamemodify(cmd.args, ":p") or vim.api.nvim_buf_get_name(0)
      if not path:lower():match "%.svg$" or vim.fn.filereadable(path) ~= 1 then
        vim.notify(
          "not a readable svg file: " .. (path ~= "" and path or "<unnamed buffer>"),
          vim.log.levels.error,
          { title = "SvgText" }
        )
        return
      end
      if vim.bo.modified and vim.api.nvim_buf_get_name(0) == path then
        vim.notify(
          "unsaved changes in this svg buffer; :w or abandon first",
          vim.log.levels.error,
          { title = "SvgText" }
        )
        return
      end
      -- a stale placeholder buffer from a previous hijack must not be reused:
      -- `:edit` switches to an existing buffer without re-reading it
      local stale ---@type number?
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_loaded(b) and vim.api.nvim_buf_get_name(b) == path then
          stale = b
          break
        end
      end
      if stale and stale ~= vim.api.nvim_get_current_buf() then
        if vim.bo[stale].modified then
          vim.notify(
            "unsaved changes in another buffer of this file; :w or abandon it first",
            vim.log.levels.error,
            { title = "SvgText" }
          )
          return
        end
        pcall(function() vim.cmd("bdelete! " .. stale) end)
      end
      svg_enabled = false
      sync()
      if vim.bo.modified then vim.cmd "split" end -- keep unsaved work in this window
      vim.cmd("edit " .. vim.fn.fnameescape(path))
      -- the buffer may have been a read-only image buffer; restore editability
      vim.bo.modifiable = true
      vim.bo.readonly = false
      vim.bo.filetype = vim.filetype.match { filename = path } or "xml"
      pcall(function() require("snacks.image.placement").clean(0) end)
    end, { nargs = "?", complete = "file", desc = "Open an svg as text (turns svg image buffers off)" })

    vim.api.nvim_create_user_command("SvgImages", function(cmd)
      svg_enabled = cmd.args == "on"
      sync()
      vim.notify(
        "svg image buffers " .. (svg_enabled and "enabled" or "disabled"),
        vim.log.levels.info,
        { title = "SvgImages" }
      )
    end, {
      nargs = 1,
      complete = function()
        return { "on", "off" }
      end,
      desc = "Toggle svg image buffers",
    })
  end,
}
