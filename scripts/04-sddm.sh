phase "SDDM Display Manager"

pacman -S --noconfirm --needed sddm
SESSION_DIR="/usr/share/wayland-sessions"
if [ ! -f "$SESSION_DIR/niri.desktop" ]; then
  mkdir -p "$SESSION_DIR"
  cp "$INSTALLER_SYS_CONFIG_DIR/sddm/niri.desktop" "$SESSION_DIR/niri.desktop"
  info "Niri session file created"
else
  info "Niri session file already exists"
fi

SDDM_AUTOLOGIN_DIR="/etc/sddm.conf.d"
mkdir -p "$SDDM_AUTOLOGIN_DIR"
sed "s/__USER__/$REAL_USER/g" "$INSTALLER_SYS_CONFIG_DIR/sddm/autologin.conf" >"$SDDM_AUTOLOGIN_DIR/autologin.conf"

info "SDDM autologin configured for user $REAL_USER"

info "Removing gnome-keyring from SDDM autologin PAM..."
# Prevents passwordless autologin from creating an encrypted login keyring
# which would prompt for unlock on first browser launch
sed -i '/pam_gnome_keyring\.so/d' /etc/pam.d/sddm-autologin 2>/dev/null || true

info "SDDM complete"
