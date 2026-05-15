# 05-nvidia.sh — NVIDIA driver configuration

do_nvidia() {
  phase "NVIDIA Configuration"

  if ! lspci | grep -i nvidia &>/dev/null; then
    info "No NVIDIA GPU detected, skipping"
    return
  fi
  info "NVIDIA GPU detected"

  ENV_FILE="/etc/environment"
  LINES=(
    "GBM_BACKEND=nvidia-drm"
    "__GLX_VENDOR_LIBRARY_NAME=nvidia"
    "LIBVA_DRIVER_NAME=nvidia"
  )

  for line in "${LINES[@]}"; do
    if ! grep -q "^${line%%=*}" "$ENV_FILE" 2>/dev/null; then
      echo "$line" >>"$ENV_FILE"
    fi
  done
  info "NVIDIA environment variables set"
}
