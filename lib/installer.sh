# Sourced by install.sh; definitions only, safe to source in unit tests.
usage() {
  cat <<'EOF'
Usage: bash /path/to/eco-linux/install.sh [options]
  --profile portable|ernesto      Hardware defaults (portable)
  --apps core|personal            Application profile (personal)
  --config preserve|replace      Existing shipped files (preserve; replace backs up)
  --network preserve|networkmanager  Network service (preserve)
  --nvidia auto|open|off          Keep existing driver; known modern GPUs use open
  --autologin                    Opt into SDDM autologin (otherwise normal login)
  --firewall preserve|enable     Firewall policy (enable; refuses remote SSH setup)
  --skip-user-setup              Provision only; completion is marked incomplete
  --help
Run interactively as a sudo-capable user. Disks, encryption and bootloader are untouched.
AUR PKGBUILDs require review and may request your normal sudo password.
EOF
}

parse_options() {
  ECO_PROFILE=portable ECO_APPS=personal ECO_CONFIG_MODE=preserve
  ECO_NETWORK=preserve ECO_NVIDIA=auto ECO_AUTOLOGIN=0 ECO_FIREWALL=enable ECO_SKIP_USER_SETUP=0
  while (($#)); do
    case $1 in
      --help) usage; exit 0;;
      --autologin) ECO_AUTOLOGIN=1; shift; continue;;
      --skip-user-setup) ECO_SKIP_USER_SETUP=1; shift; continue;;
      --profile|--apps|--config|--network|--nvidia|--firewall)
        (($# >= 2)) || error "Missing value for $1"
        case "$1:$2" in
          --profile:portable|--profile:ernesto) ECO_PROFILE=$2;;
          --apps:core|--apps:personal) ECO_APPS=$2;;
          --config:preserve|--config:replace) ECO_CONFIG_MODE=$2;;
          --network:preserve|--network:networkmanager) ECO_NETWORK=$2;;
          --nvidia:auto|--nvidia:open|--nvidia:off) ECO_NVIDIA=$2;;
          --firewall:preserve|--firewall:enable) ECO_FIREWALL=$2;;
          *) error "Invalid option/value: $1 $2";;
        esac
        shift 2;;
      *) error "Unknown option: $1";;
    esac
  done
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
  # No --noconfirm: review package recipes and use the user's ordinary sudo.
  run_user yay -S --needed --aur "$@"
}

select_nvidia() {
  local pci=$1 existing=$2 choice=$3
  [[ $choice != off ]] || { printf 'off\n'; return; }
  [[ -z $existing ]] || { printf 'existing\n'; return; }
  [[ $pci == *NVIDIA* ]] || { printf 'off\n'; return; }
  if [[ $choice == open ]]; then printf 'open\n'; return; fi
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
