phase "Zsh Shell"

info "Installing zsh..."
pacman -S --noconfirm --needed zsh zsh-syntax-highlighting zsh-autosuggestions

info "Setting zsh as default shell for $REAL_USER..."
chsh -s /usr/bin/zsh "$REAL_USER" 2>/dev/null ||
  warn "Could not set default shell (run: chsh -s /usr/bin/zsh)"

info "zsh complete"
