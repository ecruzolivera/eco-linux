# 07-noctalia.sh — Noctalia Shell plugin configuration

do_noctalia() {
  phase "Noctalia Configuration"

  NOCTALIA_DIR="$REAL_HOME/.config/noctalia"
  mkdir -p "$NOCTALIA_DIR"

  cat >"$NOCTALIA_DIR/plugins.json" <<'PLUGINSEOF'
{
  "version": 1,
  "states": {
    "polkit-agent": {
      "enabled": true,
      "sourceUrl": "https://github.com/noctalia-dev/noctalia-plugins"
    }
  },
  "sources": [
    {
      "name": "Official Noctalia Plugins",
      "url": "https://github.com/noctalia-dev/noctalia-plugins",
      "enabled": true
    }
  ]
}
PLUGINSEOF

  chown -R "$REAL_USER":"$REAL_USER" "$NOCTALIA_DIR"
  info "Noctalia plugins.json written — polkit-agent will auto-install on first launch"
}
