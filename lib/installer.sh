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
    HOME="$REAL_HOME" USER="$REAL_USER" LOGNAME="$REAL_USER" "$@"
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
  # No --noconfirm: the recipe diff and the final install confirmation stay explicit.
  # Preset yay's housekeeping menus and page diffs straight to the terminal so the
  # install cannot stall at a menu or pager it never displays.
  run_user env PAGER=cat GIT_PAGER=cat yay -S --needed --aur \
    --answerclean None --answerdiff All --answeredit None --noremovemake "$@"
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
