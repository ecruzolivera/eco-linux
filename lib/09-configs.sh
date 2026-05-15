# 09-configs.sh — User application configurations

do_configs() {
  phase "User App Configurations"

  YAZI_DIR="$REAL_HOME/.config/yazi"
  mkdir -p "$YAZI_DIR"
  cp "$CACHE_DIR/configs/yazi/yazi.toml" "$YAZI_DIR/yazi.toml"
  chown -R "$REAL_USER":"$REAL_USER" "$YAZI_DIR"
  info "Yazi config written"
}
