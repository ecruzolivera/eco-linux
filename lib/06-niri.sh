# 06-niri.sh — Niri window manager configuration

do_niri() {
  phase "Niri Configuration"

  NIRI_DIR="$REAL_HOME/.config/niri"
  mkdir -p "$NIRI_DIR"

  cp "$CACHE_DIR/configs/niri/config.kdl" "$NIRI_DIR/config.kdl"
  chown -R "$REAL_USER":"$REAL_USER" "$NIRI_DIR"

  info "Niri config written to $NIRI_DIR/config.kdl"
}
