phase "copy xdg-config-home"

mkdir -p "$USER_CONFIG"

cp -rv "$INSTALLER_XDG_CONFIG_DIR"/. "$USER_CONFIG/"

info "Make $REAL_USER owner of $USER_CONFIG ..."
chown -vR "$REAL_USER":"$REAL_USER" "$USER_CONFIG"

info "copy config complete"
