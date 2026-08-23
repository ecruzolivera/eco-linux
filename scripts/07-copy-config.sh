phase "copy xdg-config-home"
mkdir -p "$USER_CONFIG"
cp -rv "$INSTALLER_XDG_CONFIG_DIR"/. "$USER_CONFIG/"
info "copy xdg-config-home completed"

info "Templating niri envs.kdl home path..."
sed -i "s|__HOME__|$REAL_HOME|g" "$USER_CONFIG/niri/envs.kdl"

phase "copy home-root-config"
cp -rv "$INSTALLER_HOME_ROOT_CONFIG_DIR"/. "$REAL_HOME/"
info "copy home-root-config completed"

phase "copy local-bin"
mkdir -p "$REAL_HOME/.local/bin/"
cp -rv "$INSTALLER_LOCAL_BIN_DIR"/. "$REAL_HOME/.local/bin/"
info "copy local-bin completed"
