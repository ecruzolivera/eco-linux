phase "Battery Charge Limit"

if [ ! -f /sys/class/power_supply/BAT0/charge_control_end_threshold ] || [ ! -f /sys/class/power_supply/BAT0/charge_control_start_threshold ]; then
  warn "Battery charge thresholds not supported on this hardware, skipping"
  return
fi

info "Installing battery charge limit service (stop 80%, start 75%)..."
cp "$INSTALLER_SYS_CONFIG_DIR/battery-charge-limit.service" /etc/systemd/system/battery-charge-limit.service
systemctl daemon-reload
systemctl enable --now battery-charge-limit.service
info "Battery charge limit configured"
