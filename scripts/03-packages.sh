phase "Packages"

PACKAGES=(
  adwaita-cursors
  bitwarden
  brightnessctl
  cava
  chezmoi
  cliphist
  cups-pk-helper
  dms-shell-niri
  firefox-developer-edition
  fuse2
  ghostty
  ghostty-nautilus
  github-cli
  glab
  grim
  i2c-tools
  iwd
  libayatana-appindicator
  matugen
  mpv
  nautilus
  neovim
  networkmanager
  noto-fonts
  noto-fonts-emoji
  pipewire
  pipewire-alsa
  pipewire-pulse
  playerctl
  power-profiles-daemon
  qt6-multimedia
  qt6ct
  slurp
  steam
  systemd
  ttf-firacode-nerd
  wireplumber
  wlsunset
  wtype
  gnome-keyring
  xdg-desktop-portal
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xwayland-satellite
  yazi
)

AUR_PKS=(
  brave-bin
  localsend-bin
)

info "Installing ${#PACKAGES[@]} packages..."
pacman -S --noconfirm --needed "${PACKAGES[@]}"
info "Official packages installed"

info "Installing ${#AUR_PKS[@]} packages..."
sudo -u "$REAL_USER" yay -S --noconfirm --needed "${AUR_PKS[@]}"
info "AUR packages installed"
