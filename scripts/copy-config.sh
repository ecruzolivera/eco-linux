phase "copy xdg-config-home"

mkdir -p "$USER_CONFIG"

cp -rv "$INSTALLER_XDG_CONFIG_DIR/*" "$USER_CONFIG/"

info "copy config complete"
