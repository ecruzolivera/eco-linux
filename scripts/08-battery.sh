phase 'Battery profile'
[[ $ECO_PROFILE == ernesto ]] || { info 'Portable profile leaves charge thresholds unchanged'; return; }
batteries=()
for battery in /sys/class/power_supply/*; do
  [[ -f $battery/type && $(cat "$battery/type") == Battery ]] || continue
  [[ -w $battery/charge_control_end_threshold && -w $battery/charge_control_start_threshold ]] || continue
  batteries+=("${battery##*/}")
done
if ((${#batteries[@]} == 0)); then warn 'Hardware does not expose supported charge thresholds'; return; fi
for battery in "${batteries[@]}"; do
  [[ $battery =~ ^[A-Za-z0-9_-]+$ ]] || error 'Unsupported battery identifier'
  destination="/etc/systemd/system/eco-battery-$battery.service"
  if [[ -e $destination ]]; then
    info "Keeping existing $destination"
  else
    sed "s/BAT0/$battery/g" "$INSTALLER_SYS_CONFIG_DIR/battery-charge-limit.service" > "$destination"
  fi
  systemctl daemon-reload
  systemctl enable --now "eco-battery-$battery.service"
done
