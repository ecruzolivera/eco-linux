# open-terminal.yazi

A Yazi plugin to open a new terminal window in the current directory. It uses
the `$TERMINAL` environment variable to determine which terminal emulator to
spawn.

## Installation

```bash
ya pkg add <your-username>/open-terminal
```

## Keybinding

Add this to your `~/.config/yazi/keymap.toml`:

```toml
[[mgr.prepend_keymap]]
on = "T"
run = "plugin open-terminal"
desc = "Open terminal in current directory"
```

## Supported Terminals

| Terminal | Auto-detected via `$TERMINAL` |
| --- | --- |
| kitty | `$TERMINAL=kitty` |
| alacritty | `$TERMINAL=alacritty` |
| wezterm | `$TERMINAL=wezterm` |
| foot | `$TERMINAL=foot` |
| gnome-terminal | `$TERMINAL=gnome-terminal` |
| konsole | `$TERMINAL=konsole` |
| xfce4-terminal | `$TERMINAL=xfce4-terminal` |
| tilix | `$TERMINAL=tilix` |
| st | `$TERMINAL=st` |
| urxvt | `$TERMINAL=urxvt` |

For unsupported terminals, it falls back to `cd <dir> && <terminal>`.

## Usage

Set `$TERMINAL` to your terminal emulator (many terminals set this
automatically), then press the configured keybinding in Yazi. A new terminal
window opens in the directory you were browsing.
