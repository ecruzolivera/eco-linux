# Sourced by install.sh; definitions only, safe to source in unit tests.
installer_defaults() {
  ECO_PROFILE=portable ECO_APPS=personal ECO_CONFIG_MODE=replace
  ECO_FIREWALL=enable
  [[ ${ECO_REMOTE_SESSION:-0} != 1 ]] || ECO_FIREWALL=preserve
}

select_network() {
  local active enabled
  active=$(systemctl list-units --type=service --state=active --plain --no-legend --no-pager) || return
  enabled=$(systemctl list-unit-files --type=service --state=enabled --no-legend --no-pager) || return
  # Include per-interface dhcpcd and netctl instances, not just singleton units.
  if awk '{print $1}' <<< "$active"$'\n'"$enabled" |
      grep -E '^(NetworkManager|systemd-networkd|iwd|connman|dhcpcd(@[^[:space:]]+)?|netctl(-auto|-ifplugd)?(@[^[:space:]]+)?)\.service$' >/dev/null; then
    printf 'preserve\n'
  else
    printf 'networkmanager\n'
  fi
}

run_user() {
  sudo -u "$REAL_USER" -H env -u XDG_CONFIG_HOME -u XDG_DATA_HOME -u XDG_STATE_HOME -u XDG_CACHE_HOME \
    -u MISE_CONFIG_FILE -u MISE_DATA_DIR -u JAVA_HOME \
    HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" GIT_TERMINAL_PROMPT=0 "$@"
}

# Private ownership state must never come from the caller's environment.
ECO_PACMAN_GRANT_FILE= ECO_PACMAN_GRANT_STAGE= ECO_PACMAN_GRANT_ID= ECO_PACMAN_GRANT_CONTENT= ECO_PACMAN_GRANT_METADATA=

pacman_grant_owned() {
  local path=$1
  [[ -n $ECO_PACMAN_GRANT_ID && -f $path && ! -L $path ]] &&
    [[ $(stat -c '%d:%i' "$path") == "$ECO_PACMAN_GRANT_ID" &&
       $(stat -c '%u:%g:%a' "$path") == "$ECO_PACMAN_GRANT_METADATA" &&
       $(cat "$path") == "$ECO_PACMAN_GRANT_CONTENT" ]]
}

begin_pacman_grant() {
  local directory=${1:?Sudoers directory required} destination mode
  if [[ -n $ECO_PACMAN_GRANT_FILE ]]; then
    pacman_grant_owned "$ECO_PACMAN_GRANT_FILE" || error 'Temporary pacman rule changed; inspect it manually'
    return
  fi
  [[ $(id -u) == 0 ]] || error 'Temporary pacman authorization requires root'
  [[ $REAL_USER =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ && $REAL_UID =~ ^[0-9]+$ && $REAL_UID != 0 ]] || error 'Invalid account for pacman authorization'
  [[ -d $directory && ! -L $directory && $(stat -c %u "$directory") == 0 ]] || error 'Unsafe sudoers directory'
  mode=$(stat -c %a "$directory")
  (( (8#$mode & 0022) == 0 )) || error 'Sudoers directory must not be group/world writable'
  destination=$directory/99-eco-pacman-$REAL_UID
  [[ ! -e $destination && ! -L $destination ]] || error "Existing pacman rule preserved; inspect/remove it manually: $destination"

  # Dot-prefixed staging files are ignored by sudo's includedir. Validate before
  # atomic activation; ln refuses an existing destination instead of replacing it.
  ECO_PACMAN_GRANT_STAGE=$(mktemp "$directory/.eco-pacman-$REAL_UID-XXXXXXXX")
  ECO_PACMAN_GRANT_ID=$(stat -c '%d:%i' "$ECO_PACMAN_GRANT_STAGE")
  ECO_PACMAN_GRANT_METADATA=$(stat -c '%u:%g:%a' "$ECO_PACMAN_GRANT_STAGE")
  ECO_PACMAN_GRANT_CONTENT="$REAL_USER ALL=(root) NOPASSWD: /usr/bin/pacman"
  printf '%s\n' "$ECO_PACMAN_GRANT_CONTENT" > "$ECO_PACMAN_GRANT_STAGE"
  chown root:root "$ECO_PACMAN_GRANT_STAGE"
  chmod 0440 "$ECO_PACMAN_GRANT_STAGE"
  ECO_PACMAN_GRANT_METADATA=$(stat -c '%u:%g:%a' "$ECO_PACMAN_GRANT_STAGE")
  visudo -cf "$ECO_PACMAN_GRANT_STAGE" || error 'Temporary pacman rule failed validation'
  ECO_PACMAN_GRANT_FILE=$destination
  ln -T -- "$ECO_PACMAN_GRANT_STAGE" "$destination" || error 'Could not activate temporary pacman rule; existing files preserved'
  rm -- "$ECO_PACMAN_GRANT_STAGE"
  ECO_PACMAN_GRANT_STAGE=
  # makepkg uses sudo -k: prove the rule works without cached authentication.
  run_user sudo -k -n -- /usr/bin/pacman -Qq >/dev/null || error 'Temporary pacman authorization is not effective; inspect sudo policy'
  info 'Temporary pacman-only authorization enabled for package setup'
}

end_pacman_grant() {
  local path failed=0
  for path in "$ECO_PACMAN_GRANT_FILE" "$ECO_PACMAN_GRANT_STAGE"; do
    [[ -n $path && ( -e $path || -L $path ) ]] || continue
    if ! pacman_grant_owned "$path"; then
      warn "Changed temporary sudoers file preserved; inspect it manually: $path"
      failed=1
      continue
    fi
    if ! rm -- "$path"; then
      warn "Could not remove temporary sudoers file: $path"
      failed=1
    fi
  done
  ((failed == 0)) || return 1
  ECO_PACMAN_GRANT_FILE= ECO_PACMAN_GRANT_STAGE= ECO_PACMAN_GRANT_ID= ECO_PACMAN_GRANT_CONTENT= ECO_PACMAN_GRANT_METADATA=
}

read_manifest() {
  local line count=0
  while IFS= read -r line || [[ -n $line ]]; do
    line=${line%%#*}
    [[ -n $line ]] || continue
    [[ $line =~ ^[a-z0-9][a-z0-9+_.-]*$ ]] || error "Invalid package entry: $line"
    ((++count))
    printf '%s\n' "$line"
  done < "$1"
  ((count > 0)) || error "Empty or unreadable package manifest: $1"
}

install_aur() {
  (($#)) || return 0
  # Running the installer authorizes the manifest. Never open an editor/pager or
  # force conflict removals, even if the user's saved yay settings enable them.
  # Yay's post-diff approval ignores --noconfirm, so disable that entire path.
  run_user env PAGER=cat GIT_PAGER=cat yay -S --needed --aur --noconfirm \
    --answerclean None --answerdiff None --answeredit None --noremovemake \
    --diffmenu=false --editmenu=false --useask=false --sudoloop=false --sudoflags=-n --pgpfetch --batchinstall "$@"
}

select_nvidia() {
  local pci=$1 existing=$2
  [[ -z $existing ]] || { printf 'existing\n'; return; }
  [[ $pci == *NVIDIA* ]] || { printf 'off\n'; return; }
  local gpu
  while IFS= read -r gpu; do
    [[ $gpu == *NVIDIA* ]] || continue
    if [[ ! $gpu =~ (Turing|Ampere|Ada|Blackwell|RTX\ [2-6][0-9]{3}|GTX\ 16[0-9]{2}|T[456]00) ]]; then
      printf 'manual\n'
      return
    fi
  done <<< "$pci"
  printf 'open\n'
}
