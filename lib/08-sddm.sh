# 08-sddm.sh — SDDM display manager and autologin

do_sddm() {
  phase "SDDM Configuration"

  SESSION_DIR="/usr/share/wayland-sessions"
  if [ ! -f "$SESSION_DIR/niri.desktop" ]; then
    mkdir -p "$SESSION_DIR"
    cp "$CACHE_DIR/configs/sddm/niri.desktop" "$SESSION_DIR/niri.desktop"
    info "Niri session file created"
  else
    info "Niri session file already exists"
  fi

  SDDM_AUTOLOGIN_DIR="/etc/sddm.conf.d"
  mkdir -p "$SDDM_AUTOLOGIN_DIR"

  cat >"$SDDM_AUTOLOGIN_DIR/autologin.conf" <<EOF
[Autologin]
User=$REAL_USER
Session=niri
EOF
  info "SDDM autologin configured for user $REAL_USER"
}
