phase 'SDDM'
destination=/etc/sddm.conf.d/autologin.conf
mkdir -p "${destination%/*}"
autologin=$(sed "s/__USER__/$REAL_USER/g" "$INSTALLER_SYS_CONFIG_DIR/sddm/autologin.conf")
if [[ -f $destination ]] && cmp -s "$destination" <(printf '%s\n' "$autologin"); then
  info "SDDM autologin already configured for $REAL_USER"
else
  if [[ -e $destination || -L $destination ]]; then
    [[ -f $destination && ! -L $destination ]] || error "Refusing to replace non-regular SDDM configuration: $destination"
    backup=$(mktemp "$destination.eco.XXXXXXXX")
    cp -p -- "$destination" "$backup"
    info "Previous SDDM autologin configuration backed up to $backup"
  fi
  printf '%s\n' "$autologin" > "$destination"
  chmod 0644 "$destination"
  info "SDDM autologin enabled for $REAL_USER (Niri)"
fi
warn 'Autologin does not unlock encrypted login keyrings; they may still require your password. PAM settings are unchanged'
# The official niri package supplies niri.desktop and niri-session.
