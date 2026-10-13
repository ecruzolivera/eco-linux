phase 'Final checks and service enablement'
# Copy/setup already ran as the target user; no recursive ownership changes.
display_manager=$(readlink /etc/systemd/system/display-manager.service || true)
if [[ -n $display_manager && $display_manager != *sddm.service ]]; then
  error "Existing display manager $display_manager preserved; switch it manually before enabling SDDM"
fi
systemctl enable sddm
systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service dms.service
systemctl enable power-profiles-daemon
run_user env "ECO_APPS=$ECO_APPS" python3 "$INSTALLER_DIR/tests/package-coverage.py" --profile "$ECO_APPS" --packages
info 'Provisioning and user-level checks completed'
info 'No disk, encryption, bootloader or snapshot configuration was performed; accounts remain separate'
warn 'Normal package-upgrade hooks may regenerate existing kernel/initramfs/boot files'
warn 'Clean-Arch VM and real GPU/suspend validation remain deferred; reproducibility is not yet proven'
info 'Reboot when ready; restore accounts, personal files and licensed applications separately'
