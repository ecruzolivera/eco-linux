# This module only copies payloads. It never installs tools, starts services,
# authenticates providers, or deletes unrelated destination files.
for legacy in "$USER_CONFIG/opencode/opencode.json" "$REAL_HOME/.zshenv" "$USER_CONFIG/opencode/skills"; do
  if [[ -e "$legacy" || -L "$legacy" ]]; then
    warn "Legacy path preserved: $legacy (review manually; it is no longer shipped)"
  fi
done

phase "copy xdg-config-home"
mkdir -p "$USER_CONFIG"
# Replace shipped files instead of following destination file symlinks. This
# also permits repeat copies over read-only package files without touching extras.
cp -prv --remove-destination "$INSTALLER_XDG_CONFIG_DIR"/. "$USER_CONFIG/"
info "copy xdg-config-home completed"

info "Templating home paths..."
# sed replacement text treats backslashes, ampersands and the delimiter specially.
escaped_home=${REAL_HOME//\\/\\\\}
escaped_home=${escaped_home//&/\\&}
escaped_home=${escaped_home//|/\\|}
for relative in niri/envs.kdl niri/dms/binds.kdl herdr/plugins/local/eco-ws-number/herdr-plugin.toml; do
  sed -i "s|__HOME__|$escaped_home|g" "$USER_CONFIG/$relative"
done

phase "copy home-root-config"
cp -prv --remove-destination "$INSTALLER_HOME_ROOT_CONFIG_DIR"/. "$REAL_HOME/"
info "copy home-root-config completed"

phase "copy local-bin"
mkdir -p "$REAL_HOME/.local/bin/"
cp -prv --remove-destination "$INSTALLER_LOCAL_BIN_DIR"/. "$REAL_HOME/.local/bin/"
info "copy local-bin completed"

phase "copy local-share"
mkdir -p "$REAL_HOME/.local/share/"
cp -prv --remove-destination "$INSTALLER_LOCAL_SHARE_DIR"/. "$REAL_HOME/.local/share/"
info "copy local-share completed"

# Git records only executable/non-executable modes. Keep the live CLI settings
# private even when the checkout has the default non-executable mode (0644).
chmod 0600 "$USER_CONFIG/opencode/cli.json"

# Yazi's pinned package files are read-only in the live configuration. Git cannot
# record that bit, so restore it explicitly for the shipped files, not user extras.
for plugin in compress smart-enter linemode-plus open-terminal pref-by-location; do
  chmod 0444 "$USER_CONFIG/yazi/plugins/$plugin.yazi/"{LICENSE,README.md,main.lua}
done
