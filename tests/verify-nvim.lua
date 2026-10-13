local root = assert(vim.env.ECO_REPO, "ECO_REPO must point to the bootstrap checkout")
for _, directory in ipairs({ "nvim", "yazi" }) do
  for _, path in ipairs(vim.fn.glob(root .. "/xdg-config/" .. directory .. "/**/*.lua", false, true)) do
    assert(loadfile(path), "Lua syntax error: " .. path)
  end
end
assert(loadfile(root .. "/lib/bootstrap-nvim.lua"), "User bootstrap Lua syntax error")

local spec = dofile(root .. "/xdg-config/nvim/lua/plugins/opencode.lua")
assert(spec.version == false and spec.branch == "main")
spec.init()
assert(vim.g.opencode_opts.server.start == false)
assert(vim.g.opencode_opts.server.url == nil)

local calls = {}
local function record(name)
  return function(...)
    calls[#calls + 1] = { name = name, args = { ... }, argc = select("#", ...) }
  end
end
package.loaded.opencode = {
  ask = record("ask"),
  prompt = record("prompt"),
  select = record("select"),
  format = function(item) return item.path .. (item.from and ("#" .. item.from[1]) or "") end,
}
package.loaded.astroui = { get_icon = function() return "" end }
local opts = { mappings = { n = { unrelated = { "keep" } }, v = {} } }
spec.specs[1].opts(nil, opts)
assert(opts.mappings.n.unrelated[1] == "keep")
local function mapping(mode, suffix, expected, text)
  local entry = assert(opts.mappings[mode]["<Leader>a" .. suffix])
  assert(entry.desc)
  entry[1]()
  local call = calls[#calls]
  assert(call.name == expected and call.argc == (text and 1 or 0))
  assert(call.args[1] == text)
end
mapping("n", "a", "ask", "@this: ")
mapping("n", "+", "ask", "@buffer ")
mapping("n", "e", "prompt", "Explain @this and its context")
mapping("n", "s", "select")
mapping("v", "a", "ask", "@this: ")
mapping("v", "+", "ask", "@this ")
mapping("v", "s", "select")
assert(opts.mappings.n["<Leader>an"] == nil)
assert(opts.mappings.n["<S-C-u>"] == nil and opts.mappings.n["<S-C-d>"] == nil)

local closed = false
spec.dependencies[1].opts.picker.actions.opencode_send({
  selected = function(_, options)
    assert(options.fallback)
    return { { file = "src/example.lua", pos = { 2, 0 } }, { text = "fixture text" } }
  end,
  close = function() closed = true end,
})
assert(closed and calls[#calls].name == "ask")
assert(calls[#calls].args[1] == "src/example.lua#2, fixture text ")

local notifications = {}
vim.notify = function(message) notifications[#notifications + 1] = message end
dofile(root .. "/xdg-config/nvim/lua/polish.lua")
for _, kind in ipairs({ "session.idle", "session.execution.started", "session.execution.failed" }) do
  vim.api.nvim_exec_autocmds("User", { pattern = "OpencodeEvent:" .. kind, data = { event = { type = kind } } })
end
assert(#notifications == 0)
vim.api.nvim_exec_autocmds("User", {
  pattern = "OpencodeEvent:session.execution.succeeded",
  data = { event = { type = "session.execution.succeeded" } },
})
assert(#notifications == 1 and notifications[1] == "`opencode` finished responding")
print("PASS: Lua syntax, seven mappings, picker review, completion event and no-terminal defaults.")
