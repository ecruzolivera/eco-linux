phase 'Graphics'
pci=$(lspci -nn | grep -E 'VGA|3D|Display' || true)
existing=$(pacman -Qq | grep -E '^nvidia(-open)?(-dkms|-lts)?$|^nvidia-[0-9]+xx-dkms$' || true)
driver=$(select_nvidia "$pci" "$existing")
case $driver in
  off) info 'No NVIDIA changes requested/needed'; return;;
  manual) warn 'Unrecognized/older NVIDIA generation: graphics changes skipped. Configure a supported driver manually before using the desktop'; return;;
  existing) info "Keeping installed driver: $existing";;
  open) info 'Detected/selected modern NVIDIA; installing nvidia-open-dkms';;
esac
headers=()
for pkgbase in /usr/lib/modules/*/pkgbase; do
  [[ -f $pkgbase ]] || continue
  kernel=$(cat "$pkgbase")
  pacman -Q "$kernel" >/dev/null 2>&1 || continue
  if [[ $driver == open || $existing == *dkms* ]]; then
    pacman -Si "$kernel-headers" >/dev/null || error "No headers for $kernel; configure custom kernel headers manually"
    headers+=("$kernel-headers")
  fi
done
if [[ $driver == open ]]; then
  ((${#headers[@]})) || error 'No installed kernel/header pair detected'
  pacman -S --needed --noconfirm nvidia-open-dkms nvidia-utils nvidia-settings egl-wayland "${headers[@]}"
elif ((${#headers[@]})); then
  pacman -S --needed --noconfirm "${headers[@]}"
fi
info 'No global NVIDIA routing variables, initramfs or bootloader changes made'
