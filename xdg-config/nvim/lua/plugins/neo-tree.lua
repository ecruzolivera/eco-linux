-- Neo-tree file explorer configuration

---@type LazySpec
return {
  "nvim-neo-tree/neo-tree.nvim",
  opts = {
    commands = {
      open_yazi = function(state)
        require("toggleterm.terminal").Terminal
          :new({
            cmd = "yazi",
            dir = state.path,
            direction = "float",
          })
          :toggle()
      end,
    },
    window = {
      width = "30%",
      position = "left",
      mappings = {
        ["E"] = "open_yazi",
      },
    },
  },
}
