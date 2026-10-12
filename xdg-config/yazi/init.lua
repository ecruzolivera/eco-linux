require("pref-by-location"):setup({
  save_path = os.getenv("HOME") .. "/.local/state/yazi/pref-by-location",
})

require("linemode-plus"):setup {
  date_mode = "custom",
  custom = { order = { "year", "month", "day" }, separator = "-", year_digits = 2 },
}