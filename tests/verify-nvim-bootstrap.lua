-- Exercise provisioning logic with inert registry/Git/editor mocks only.
local root = assert(vim.env.ECO_REPO)
local original = {
  cmd = vim.cmd,
  wait = vim.wait,
  stdpath = vim.fn.stdpath,
  system = vim.fn.system,
  isdirectory = vim.fn.isdirectory,
  error = vim.api.nvim_err_writeln,
}
local lock = vim.json.decode(table.concat(vim.fn.readfile(root .. "/xdg-config/nvim/lazy-lock.json"), "\n"))
local name = "lazy.nvim"
local expected = assert(lock[name], "Missing revision-test lock entry: " .. name)
local finished, messages, installs
local refresh_ok, install_ok, commit_ok = true, true, true
local requested_tools = {}
-- The resolved mason-tool-installer options include packs merged by AstroCommunity.
local configured_tools = { "lua-language-server", "stylua", "debugpy", "vtsls", "js-debug-adapter" }
vim.cmd = function(command) finished = command end
vim.wait = function(_, predicate) return predicate() end
vim.fn.stdpath = function(kind)
  assert(kind == "config")
  return root .. "/xdg-config/nvim"
end
vim.fn.isdirectory = function() return 1 end
vim.fn.system = function(argv)
  assert(argv[1] == "git" and argv[4] == "rev-parse")
  return commit_ok and expected.commit or "unreviewed"
end
vim.api.nvim_err_writeln = function(message) messages[#messages + 1] = message end
package.loaded["lazy.core.config"] = { plugins = {
  [name] = { dir = "/inert/plugin" },
  -- virtual avoids the lock-revision loop; the real checkout is verified after Lazy restore.
  ["mason-tool-installer.nvim"] = { name = "mason-tool-installer.nvim", virtual = true },
} }
package.loaded["lazy.core.plugin"] = {
  values = function(plugin, prop)
    assert(prop == "opts" and plugin.name == "mason-tool-installer.nvim", "Unexpected plugin values request")
    return { ensure_installed = configured_tools }
  end,
}
package.loaded["mason-registry"] = {
  refresh = function(callback) callback(refresh_ok) end,
  get_package = function(requested)
    requested_tools[#requested_tools + 1] = requested
    local installed = false
    return {
      is_installed = function() return installed end,
      is_installing = function() return false end,
      install = function() installs = installs + 1; installed = install_ok end,
    }
  end,
}
local function run()
  finished, messages, installs, requested_tools = nil, {}, 0, {}
  dofile(root .. "/lib/bootstrap-nvim.lua")
end
run()
assert(finished == "qa!" and installs > 0 and #messages == 0)
assert(vim.deep_equal(configured_tools, requested_tools), "Bootstrap must install the resolved tool list")
refresh_ok = false
run()
assert(finished == "cquit 1" and installs == 0 and messages[1]:find("refresh failed", 1, true))
refresh_ok, install_ok = true, false
run()
assert(finished == "cquit 1" and messages[1]:find("failed to install", 1, true))
install_ok, commit_ok = true, false
run()
assert(finished == "cquit 1" and messages[1]:find("revision mismatch", 1, true))
vim.cmd, vim.wait = original.cmd, original.wait
vim.fn.stdpath, vim.fn.system, vim.fn.isdirectory = original.stdpath, original.system, original.isdirectory
vim.api.nvim_err_writeln = original.error
print("PASS: Neovim provisioning mocks: success, registry failure, tool failure and revision mismatch; no downloads.")
