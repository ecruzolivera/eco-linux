phase "Final Setup"

info "Make $REAL_USER owner of $REAL_HOME ..."
chown -vR "$REAL_USER":"$REAL_USER" "$REAL_HOME/.config" "$REAL_HOME/.local/bin"
find "$HOME" -maxdepth 1 -type f -exec chown -v "$REAL_USER":"$REAL_USER" {} +

info "Enabling SDDM..."
systemctl enable sddm

info "Enabling PipeWire user services..."
systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service

info "Adding $REAL_USER to relevant groups..."
usermod -aG audio,video,input "$REAL_USER" 2>/dev/null || true

info ""
echo -e "${GREEN}eco-linux installation complete!${NC}"

info "Reboot when ready: sudo systemctl reboot"
