phase 'SDDM'
if [[ $ECO_AUTOLOGIN == 1 ]]; then
  destination=/etc/sddm.conf.d/autologin.conf
  mkdir -p "${destination%/*}"
  [[ ! -e $destination ]] || cp -p "$destination" "$destination.eco-$(date +%Y%m%d-%H%M%S)"
  sed "s/__USER__/$REAL_USER/g" "$INSTALLER_SYS_CONFIG_DIR/sddm/autologin.conf" > "$destination"
  warn 'Autologin selected: encrypted login keyrings may still require manual unlocking'
else
  info 'Normal login selected; existing autologin/PAM configuration is not edited'
fi
# The official niri package supplies niri.desktop and niri-session.
