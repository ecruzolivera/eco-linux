# 05-nvidia.sh — NVIDIA driver configuration

do_nvidia() {
  phase "NVIDIA Configuration"

  if ! lspci | grep -i nvidia &>/dev/null; then
    info "No NVIDIA GPU detected, skipping"
    return
  fi
  info "NVIDIA GPU detected"

  info "Installing NVIDIA drivers..."
  pacman -S --noconfirm --needed nvidia-dkms nvidia-utils nvidia-settings egl-wayland

  info "Setting NVIDIA environment variables..."
  while IFS= read -r line; do
    if ! grep -q "^${line%%=*}" /etc/environment 2>/dev/null; then
      echo "$line" >> /etc/environment
    fi
  done < configs/environment
  info "NVIDIA configuration complete"
}
