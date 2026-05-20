phase "chezmoi bootstrap"

CHEZMOI_SOURCE_DIR="$REAL_HOME/.local/share/chezmoi"

chown -R "$REAL_USER":"$REAL_USER" "$USER_CONFIG" 2>/dev/null || true

if [ -d "$CHEZMOI_SOURCE_DIR" ]; then
  info "chezmoi already initialized, running update..."
  sudo -u "$REAL_USER" chezmoi update
else
  info "Initializing chezmoi from dotfiles repo..."
  sudo -u "$REAL_USER" chezmoi init --apply https://github.com/ecruzolivera/dotfiles.git
fi

info "chezmoi bootstrap complete"
