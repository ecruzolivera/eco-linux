# If not running interactively, don't do anything (leave this at the top of this file)
[[ $- != *i* ]] && return

source ~/.profile

# All the default Omarchy aliases and functions
# (don't mess with these directly, just overwrite them here!)
source ~/.local/share/omarchy/default/bash/rc

# Add your own exports, aliases, and functions here.
#
# Make an alias for invoking commands you use constantly
# alias p='python'

if command -v wt >/dev/null 2>&1; then eval "$(command wt config shell init bash)"; fi
. "$HOME/.cargo/env"
