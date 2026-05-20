# 05b-zsh.sh — Install zsh and set as default shell

do_zsh() {
  phase "Zsh Shell"

  info "Installing zsh..."
  pacman -S --noconfirm --needed zsh

  info "Setting zsh as default shell for $REAL_USER..."
  chsh -s /usr/bin/zsh "$REAL_USER" 2>/dev/null || \
    warn "Could not set default shell (run: chsh -s /usr/bin/zsh)"

  info "zsh configured"
}
