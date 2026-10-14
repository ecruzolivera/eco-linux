phase 'AUR helper'
if command -v yay >/dev/null; then
  info 'yay already installed'
  return
fi
# Subshell scopes both cwd and cleanup; never remove a shared /tmp/yay-bin.
(
  parent=/tmp
  [[ ! -d /tmp/opencode ]] || parent=/tmp/opencode
  build=$(mktemp -d "$parent/eco-yay.XXXXXXXX")
  trap 'rm -rf -- "$build"' EXIT
  chown "$REAL_UID:$REAL_GID" "$build"
  run_user git clone https://aur.archlinux.org/yay-bin.git "$build/source"
  info 'Installing yay-bin automatically; recipe follows'
  cat "$build/source/PKGBUILD"
  cd "$build/source"
  run_user makepkg --syncdeps --cleanbuild --noconfirm
  mapfile -t artifacts < <(run_user makepkg --packagelist)
  ((${#artifacts[@]})) || error 'No yay artifacts produced'
  pacman -U --needed --noconfirm "${artifacts[@]}"
)
