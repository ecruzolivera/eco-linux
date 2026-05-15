# 01-system.sh — System update and base tooling

do_system() {
  phase "System Preparation"

  info "Updating package databases..."
  pacman -Sy --noconfirm

  if ! grep -q '^\[multilib\]' /etc/pacman.conf; then
    info "Enabling multilib repository..."
    echo -e "\n[multilib]\nInclude = /etc/pacman.d/mirrorlist" >>/etc/pacman.conf
    pacman -Sy --noconfirm
  fi
  info "Multilib enabled"

  info "Installing base-devel and git..."
  pacman -S --noconfirm --needed base-devel git

  if [ ! -d "$REAL_HOME/.config" ]; then
    mkdir -p "$REAL_HOME/.config"
    chown -R "$REAL_USER":"$REAL_USER" "$REAL_HOME/.config"
  fi
}
