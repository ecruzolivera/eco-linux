# 03-packages-official.sh — Install official repository packages

do_official_packages() {
  phase "Official Packages"

  PACKAGES=(
    niri
    xwayland-satellite
    ghostty
    yazi
    nautilus
    firefox-developer-edition
    steam
    github-cli
    glab
    neovim
    mpv
    bitwarden
    grim
    slurp
    sddm
    pipewire
    wireplumber
    pipewire-pulse
    pipewire-alsa
    xdg-desktop-portal
    xdg-desktop-portal-gtk
    noto-fonts
    noto-fonts-emoji
    ttf-firacode-nerd
    fuse2
    libayatana-appindicator
    brightnessctl
    playerctl
    # Noctalia Shell optional dependencies
    cliphist
    wlsunset
    power-profiles-daemon
    ddcutil
  )

  info "Installing ${#PACKAGES[@]} packages..."
  pacman -S --noconfirm --needed "${PACKAGES[@]}"
  info "Official packages installed"
}
