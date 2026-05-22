phase "Packages"

PACKAGES=(
  adwaita-cursors
  alacritty
  atool
  bat
  bitwarden
  bluetui
  bottom
  brightnessctl
  cava
  chezmoi
  chromium
  cliphist
  cups-pdf
  cups-pk-helper
  dgop
  diff-so-fancy
  dms-shell-niri
  docker-compose
  eza
  fastfetch
  ffmpegthumbnailer
  firefox-developer-edition
  font-manager
  fprintd
  fuse2
  fzf
  gdb
  ghostty
  ghostty-nautilus
  gimp
  git-lfs
  github-cli
  glab
  gnome-boxes
  gnome-calculator
  gnome-characters
  gnome-disk-utility
  gnome-keyring
  gnome-themes-extra
  gparted
  grim
  hunspell-es_any
  i2c-tools
  imath
  imv
  iwd
  just
  jxrlib
  karchive
  kimageformats
  lazygit
  libavif
  libayatana-appindicator
  libheif
  libjxl
  libraw
  lldb
  lshw
  luarocks
  matugen
  mise
  mpv
  nano
  nautilus
  neovim
  networkmanager
  noto-fonts
  noto-fonts-emoji
  obsidian
  openexr
  openjpeg2
  pipewire
  pipewire-alsa
  pipewire-pulse
  playerctl
  power-profiles-daemon
  qbittorrent
  qt6-multimedia
  qt6ct
  satty
  sddm
  steam
  systemd
  tree-sitter-cli
  ttf-firacode-nerd
  wf-recorder
  xdg-desktop-portal
  xdg-desktop-portal-gnome
  xdg-desktop-portal-gtk
  xwayland-satellite
  yazi
)

AUR_PKS=(
  brave-bin
  limine-snapper-sync
  localsend-bin
  megasync-bin
  oh-my-zsh-git
  riskie-bin
  roll
  ufw-docker
  worktrunk-bin
)

info "Installing ${#PACKAGES[@]} packages..."
pacman -S --noconfirm --needed "${PACKAGES[@]}"
info "Official packages installed"

info "Installing ${#AUR_PKS[@]} packages..."
info "Granting temporary passwordless pacman for AUR build..."
echo "$REAL_USER ALL=(ALL) NOPASSWD: /usr/bin/pacman" >/etc/sudoers.d/99-eco-nopasswd
chmod 0440 /etc/sudoers.d/99-eco-nopasswd

sudo -u "$REAL_USER" yay -S --noconfirm --needed "${AUR_PKS[@]}"

info "Removing temporary passwordless pacman..."
rm -f /etc/sudoers.d/99-eco-nopasswd
info "AUR packages installed"
