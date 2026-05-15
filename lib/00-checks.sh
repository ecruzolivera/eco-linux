# 00-checks.sh — Pre-flight validation

do_checks() {
  phase "Pre-flight Checks"

  if [ ! -f /etc/arch-release ]; then
    error "This script is for Arch Linux only"
  fi
  info "Arch Linux detected"

  if [ "$(id -u)" -ne 0 ]; then
    error "Must run as root"
  fi
  info "Running as root"

  REAL_USER="${SUDO_USER:-}"
  if [ -z "$REAL_USER" ]; then
    error "Could not detect the non-root user. Run with sudo."
  fi

  REAL_HOME=$(eval echo "~$REAL_USER")
  if [ ! -d "$REAL_HOME" ]; then
    error "Home directory for $REAL_USER not found"
  fi
  info "Target user: $REAL_USER"
  info "Target home: $REAL_HOME"

  if ! ping -c 1 archlinux.org &>/dev/null && ! ping -c 1 google.com &>/dev/null; then
    error "No internet connection"
  fi
  info "Internet OK"

  if ! sudo -n true 2>/dev/null; then
    warn "Passwordless sudo is recommended for non-interactive install"
  fi
}
