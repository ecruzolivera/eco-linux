phase 'Preflight checks'
[[ -f /etc/arch-release ]] || error 'Arch Linux is required'
[[ $(uname -m) == x86_64 ]] || error 'Only x86_64 Arch is supported'
[[ $(id -u) == 0 && -n ${SUDO_USER:-} && $SUDO_USER != root ]] || error 'Run from a sudo-capable normal user, not a root login'
REAL_USER=$SUDO_USER
[[ $REAL_USER =~ ^[a-zA-Z_][a-zA-Z0-9_-]*\$?$ ]] || error 'Unsupported target account name'
account=$(getent passwd "$REAL_USER") || error 'Target account not found'
IFS=: read -r _ _ REAL_UID REAL_GID _ REAL_HOME _ <<< "$account"
[[ $REAL_UID != 0 && $REAL_HOME == /* && -d $REAL_HOME ]] || error 'Invalid target user/home'
[[ $(stat -c %u "$REAL_HOME") == "$REAL_UID" ]] || error 'Target user must own their home directory'
USER_CONFIG=$REAL_HOME/.config
[[ -t 0 && -t 1 ]] || error 'Use an interactive terminal for sudo authentication'
for command in sudo pacman getent curl tar git awk grep sed cp find mktemp systemctl; do
  # git is installed in phase 01; it is not a prerequisite on minimal Arch.
  [[ $command != git ]] || continue
  command -v "$command" >/dev/null || error "Missing bootstrap command: $command"
done
curl --fail --silent --show-error --location --max-time 20 --proto '=https' https://archlinux.org/ -o /dev/null || error 'HTTPS connectivity/DNS check failed'
# As root, inspect the target user's sudo policy without prompting a second time.
sudo -l -U "$REAL_USER" >/dev/null 2>&1 || error 'Target user must have ordinary sudo access for AUR dependencies'
[[ $ECO_FIREWALL != preserve ]] || warn 'SSH session detected: firewall policy will be preserved to avoid locking you out'
if grep -Eq '^\[omarchy\]' /etc/pacman.conf; then
  error 'Disable the Omarchy repository separately before installing; this installer does not migrate existing repositories'
fi
[[ ! -e /etc/sudoers.d/99-eco-nopasswd ]] || error 'Legacy eco sudoers grant found; review/remove it manually before continuing'
display_manager=$(readlink /etc/systemd/system/display-manager.service || true)
[[ -z $display_manager || $display_manager == *sddm.service ]] || error 'Switch the existing display manager manually before selecting SDDM'
ECO_NETWORK=$(select_network)
info "Target: $REAL_USER ($REAL_HOME); hardware: $ECO_PROFILE; apps: $ECO_APPS"
