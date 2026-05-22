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

# Give this user privileged Docker access
sudo usermod -aG docker "${REAL_USER}"

# Allow nothing in, everything out
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow ports for LocalSend
sudo ufw allow 53317/udp
sudo ufw allow 53317/tcp

# Allow Docker containers to use DNS on host
sudo ufw allow in proto udp from 172.16.0.0/12 to 172.17.0.1 port 53 comment 'allow-docker-dns'
sudo ufw allow in proto udp from 192.168.0.0/16 to 172.17.0.1 port 53 comment 'allow-docker-dns'

# Turn on the firewall
sudo ufw --force enable

# Enable UFW systemd service to start on boot
sudo systemctl enable ufw

# Turn on Docker protections
sudo ufw-docker install
sudo ufw reload

info ""
echo -e "${GREEN}eco-linux installation complete!${NC}"

info "Reboot when ready: sudo systemctl reboot"
