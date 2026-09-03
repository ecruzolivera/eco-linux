# export QT_STYLE_OVERRIDE=kvantum
# export QT_QPA_PLATFORMTHEME=qt5ct
# [[ -n "$WAYLAND_DISPLAY" ]] && export QT_QPA_PLATFORM=wayland
# export QT_QPA_PLATFORMTHEME=gtk2
export TERMINAL=kitty
export SYSTEMD_EDITOR=nvim
export EDITOR=nvim
export BROWSER=brave
export SSH_AUTH_SOCK="$HOME/.bitwarden-ssh-agent.sock"
[[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
export FZF_DEFAULT_OPTS="--color=fg:#faf8ff,bg:#141218,hl:#d7c6ff,fg+:#faf8ff,bg+:#9d99a5,hl+:#d7c6ff,info:#d7c6ff,prompt:#d7c6ff,pointer:#ff9fb2,marker:#a5ffb8,spinner:#d7c6ff,header:#d7c6ff,border:#9d99a5 --layout=reverse --border --prompt='❯ ' --pointer='›'"
