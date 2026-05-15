# 04-packages-aur.sh — Install AUR packages

do_aur_packages() {
  phase "AUR Packages"

  AUR_PACKAGES=(
    noctalia-shell
    localsend-bin
    brave-bin
  )

  info "Installing AUR packages: ${AUR_PACKAGES[*]}"
  sudo -u "$REAL_USER" yay -S --noconfirm --needed "${AUR_PACKAGES[@]}"
  info "AUR packages installed"
}
