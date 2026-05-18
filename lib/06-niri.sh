# 06-niri.sh — Niri window manager configuration

do_niri() {
  phase "Niri Configuration"

  NIRI_DIR="$REAL_HOME/.config/niri"
  mkdir -p "$NIRI_DIR"

  cp -r "$CACHE_DIR/configs/niri/." "$NIRI_DIR"
  chown -R "$REAL_USER":"$REAL_USER" "$NIRI_DIR"

  info "Niri config written to $NIRI_DIR"
}
