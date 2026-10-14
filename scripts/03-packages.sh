phase 'Application manifests'
package_lines=$(read_manifest "$INSTALLER_DIR/packages/core.official")
mapfile -t PACKAGES <<< "$package_lines"
package_lines=$(read_manifest "$INSTALLER_DIR/packages/core.aur")
mapfile -t AUR_PACKAGES <<< "$package_lines"
if [[ $ECO_APPS == personal ]]; then
  package_lines=$(read_manifest "$INSTALLER_DIR/packages/personal.official")
  mapfile -t PERSONAL <<< "$package_lines"
  PACKAGES+=("${PERSONAL[@]}")
  package_lines=$(read_manifest "$INSTALLER_DIR/packages/personal.aur")
  mapfile -t PERSONAL <<< "$package_lines"
  AUR_PACKAGES+=("${PERSONAL[@]}")
fi
# Official repositories are trusted upstream packages, so no per-package confirmation.
pacman -S --needed --noconfirm "${PACKAGES[@]}"
install_aur "${AUR_PACKAGES[@]}"
# Only this compatibility-sensitive pair is pinned. Other apps track current Arch/AUR.
# Read the manifest on fd 3, leaving stdin available for sudo authentication.
PENDING_PINS=()
while read -r name revision version <&3; do
  [[ -n $name && $name != \#* ]] || continue
  installed=$(pacman -Q "$name" 2>/dev/null || true)
  if [[ $installed == "$name $version" ]]; then continue; fi
  PENDING_PINS+=("$name $revision $version")
done 3< "$INSTALLER_DIR/packages/integrations.lock"
if ((${#PENDING_PINS[@]})); then
  (
    parent=/tmp
    [[ ! -d /tmp/opencode ]] || parent=/tmp/opencode
    build=$(mktemp -d "$parent/eco-aur.XXXXXXXX")
    trap 'rm -rf -- "$build"' EXIT
    chown "$REAL_UID:$REAL_GID" "$build"
    # Fetch and print the pinned recipes before automatically building them.
    for pin in "${PENDING_PINS[@]}"; do
      read -r name revision version <<< "$pin"
      run_user git clone "https://aur.archlinux.org/$name.git" "$build/$name"
      run_user git -C "$build/$name" checkout --detach "$revision"
      printf '\n───── reviewed integration recipe: %s %s (%s) ─────\n' "$name" "$version" "$revision"
      cat "$build/$name/PKGBUILD"
    done
    info "Installing ${#PENDING_PINS[@]} pinned integration package(s) automatically"
    for pin in "${PENDING_PINS[@]}"; do
      read -r name revision version <<< "$pin"
      (
        cd "$build/$name"
        run_user makepkg --syncdeps --cleanbuild --noconfirm
        mapfile -t artifacts < <(run_user makepkg --packagelist)
        ((${#artifacts[@]})) || error "No pinned package artifacts produced: $name"
        pacman -U --needed --noconfirm "${artifacts[@]}"
      )
      [[ $(pacman -Q "$name") == "$name $version" ]] || error "Expected $name $version"
    done
  )
fi
