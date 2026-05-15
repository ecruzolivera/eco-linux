# 02-yay.sh — Install yay AUR helper

do_yay() {
  phase "AUR Helper (yay)"

  if command -v yay &>/dev/null; then
    info "yay already installed, skipping"
    return
  fi

  YAY_DIR="/tmp/yay-bin"
  rm -rf "$YAY_DIR"

  info "Cloning yay-bin..."
  sudo -u "$REAL_USER" git clone --depth 1 https://aur.archlinux.org/yay-bin.git "$YAY_DIR"

  info "Building yay..."
  cd "$YAY_DIR"
  sudo -u "$REAL_USER" makepkg --noconfirm

  info "Installing yay..."
  pacman -U --noconfirm yay-bin-*.pkg.tar.zst

  cd /tmp
  info "yay installed successfully"
}
