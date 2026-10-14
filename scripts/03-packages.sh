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
# The manifest is read from fd 3 so the confirmation/sudo prompts keep the terminal on stdin.
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
    # Fetch every pinned recipe first, then review them together in one decision.
    for pin in "${PENDING_PINS[@]}"; do
      read -r name revision version <<< "$pin"
      run_user git clone "https://aur.archlinux.org/$name.git" "$build/$name"
      run_user git -C "$build/$name" checkout --detach "$revision"
      printf '\n───── reviewed integration recipe: %s %s (%s) ─────\n' "$name" "$version" "$revision"
      cat "$build/$name/PKGBUILD"
    done
    printf '\n%s pinned integration recipe(s) uphold the shipped Herdr/OpenCode patch.\n' "${#PENDING_PINS[@]}"
    read -r -p 'Build all reviewed integration recipes? [y/N] ' answer
    [[ $answer == y || $answer == Y ]] || error 'Pinned integration packages declined'
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
