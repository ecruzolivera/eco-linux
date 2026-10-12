local get_cwd = ya.sync(function()
	return tostring(cx.active.current.cwd)
end)

local TERMINAL_FLAGS = {
	kitty = "--directory",
	alacritty = "--working-directory",
	wezterm = "start --cwd",
	foot = "--working-directory",
	["gnome-terminal"] = "--working-directory",
	konsole = "--workdir",
	["xfce4-terminal"] = "--working-directory",
	tilix = "--working-directory",
	st = "-d",
	urxvt = "-cd",
}

return {
	entry = function()
		local cwd = get_cwd()
		local terminal = os.getenv("TERMINAL") or ""
		if terminal == "" then
			ya.notify({ title = "open-terminal", content = "$TERMINAL is not set", level = "error", timeout = 3 })
			return
		end

		local term_name = terminal:match(".*/([^/]+)$") or terminal:gsub("%.exe$", "")
		local dir_flag = TERMINAL_FLAGS[term_name]

		local cmd
		if dir_flag then
			cmd = string.format('%s %s "%s"', terminal, dir_flag, cwd)
		else
			cmd = string.format('cd "%s" && %s', cwd, terminal)
		end

		ya.emit("shell", { cmd, orphan = true })
	end,
}
