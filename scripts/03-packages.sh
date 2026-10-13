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
pacman -S --needed "${PACKAGES[@]}"
install_aur "${AUR_PACKAGES[@]}"
# Only this compatibility-sensitive pair is pinned. Other apps track current Arch/AUR.
# The manifest is read from fd 3 so the confirmation/sudo prompts keep the terminal on stdin.
while read -r name revision version <&3; do
  [[ -n $name && $name != \#* ]] || continue
  installed=$(pacman -Q "$name" 2>/dev/null || true)
  if [[ $installed == "$name $version" ]]; then continue; fi
  (
    parent=/tmp
    [[ ! -d /tmp/opencode ]] || parent=/tmp/opencode
    build=$(mktemp -d "$parent/eco-aur.XXXXXXXX")
    trap 'rm -rf -- "$build"' EXIT
    chown "$REAL_UID:$REAL_GID" "$build"
    run_user git clone "https://aur.archlinux.org/$name.git" "$build/source"
    cd "$build/source"
    run_user git checkout --detach "$revision"
    cat PKGBUILD
    read -r -p "Build reviewed $name $version recipe? [y/N] " answer
    [[ $answer == y || $answer == Y ]] || error 'Pinned integration package declined'
    run_user makepkg --syncdeps --cleanbuild
    mapfile -t artifacts < <(run_user makepkg --packagelist)
    ((${#artifacts[@]})) || error 'No pinned package artifacts produced'
    pacman -U --needed "${artifacts[@]}"
  )
  [[ $(pacman -Q "$name") == "$name $version" ]] || error "Expected $name $version"
done 3< "$INSTALLER_DIR/packages/integrations.lock"
