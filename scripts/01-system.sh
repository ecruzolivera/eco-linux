phase 'System preparation'
if ! grep -Eq '^\[multilib\]' /etc/pacman.conf; then
  cp -p /etc/pacman.conf "/etc/pacman.conf.eco-$(date +%Y%m%d-%H%M%S)"
  printf '\n[multilib]\nInclude = /etc/pacman.d/mirrorlist\n' >> /etc/pacman.conf
fi
info 'Performing a full official-repository upgrade and installing bootstrap tools'
pacman -Syu --needed --noconfirm base-devel git curl python sudo
