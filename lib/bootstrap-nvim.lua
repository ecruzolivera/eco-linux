-- Normal-user provisioning only; never used by the safe local test harness.
-- The configured tools come from the resolved mason-tool-installer options, which
-- include the packs merged by AstroCommunity (vtsls, js-debug-adapter, ...).
local function mason_tool_names()
  local config = require("lazy.core.config")
  local plugin = config.plugins["mason-tool-installer.nvim"]
  assert(plugin, "mason-tool-installer is not configured")
  local opts = require("lazy.core.plugin").values(plugin, "opts")
  local names = {}
  for _, entry in ipairs(opts.ensure_installed or {}) do
    local name = type(entry) == "table" and entry[1] or entry
    assert(type(name) == "string" and name ~= "", "Invalid Mason tool entry")
    table.insert(names, name)
  end
  assert(#names > 0, "No Mason tools are configured")
  return names
end

local function bootstrap()
  local registry = require "mason-registry"
  local refreshed, refresh_ok = false, false
  registry.refresh(function(success)
    refresh_ok, refreshed = success, true
  end)
  assert(vim.wait(120000, function() return refreshed end, 100), "Mason registry refresh timed out")
  assert(refresh_ok, "Mason registry refresh failed")
  local packages = {}
  for _, name in ipairs(mason_tool_names()) do
    local package = registry.get_package(name)
    table.insert(packages, package)
    if not package:is_installed() and not package:is_installing() then package:install() end
  end
  assert(vim.wait(900000, function()
    for _, package in ipairs(packages) do
      if not package:is_installed() then return false end
    end
    return true
  end, 250), "Required Mason tools failed to install")
  -- Verify enabled, locked plugins; Lazy can otherwise log an error and exit 0.
  local lock_path = vim.env.ECO_NVIM_LOCK_FILE or (vim.fn.stdpath "config" .. "/lazy-lock.json")
  local lock = vim.json.decode(table.concat(vim.fn.readfile(lock_path), "\n"))
  for name, plugin in pairs(require("lazy.core.config").plugins) do
    if lock[name] and not plugin.virtual then
      assert(vim.fn.isdirectory(plugin.dir) == 1, "Missing plugin " .. name)
      local commit = vim.trim(vim.fn.system({ "git", "-C", plugin.dir, "rev-parse", "HEAD" }))
      assert(vim.v.shell_error == 0 and commit == lock[name].commit, "Plugin revision mismatch: " .. name)
    end
  end
end

local ok, message = pcall(bootstrap)
if not ok then
  vim.api.nvim_err_writeln(tostring(message))
  vim.cmd "cquit 1"
else
  vim.cmd "qa!"
end
