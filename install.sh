#!/bin/bash
set -Eeuo pipefail

info() { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ⚠ %s\n' "$*" >&2; }
error() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
phase() { printf '\n━━━ %s ━━━\n' "$*"; }

usage() {
  cat <<'EOF'
Usage: curl -fsSL https://raw.githubusercontent.com/ecruzolivera/eco-linux/master/install.sh | bash
       bash /path/to/eco-linux/install.sh
Installs the full desktop, applications, configuration and user tools. No options needed.
Run in a terminal as a normal sudo-capable user on bootable x86_64 Arch with internet,
curl and Git. Changed shipped configurations are backed up before replacement.
Sudo and AUR package review remain interactive. Disks and bootloader are untouched.
EOF
}

# Bash parses the whole function before running it, so prompts cannot consume
# partially downloaded script text. The final call is the only entrypoint.
main() {
  if [[ $# == 1 && $1 == --help ]]; then usage; return; fi
  (($# == 0)) || error 'No installation options are needed; use --help for usage'

  SCRIPT_DIR=
  if [[ -n ${BASH_SOURCE[0]:-} && -f ${BASH_SOURCE[0]} ]]; then
    SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
  fi
  # Piped scripts always bootstrap; never use a checkout in the caller's cwd.
  if [[ -z $SCRIPT_DIR || ! -f "$SCRIPT_DIR/scripts/00-checks.sh" || ! -f "$SCRIPT_DIR/lib/installer.sh" ]]; then
    [[ $(id -u) != 0 ]] || error 'Run the bootstrap as your normal user without sudo; it escalates itself'
    for command in git mktemp sudo; do command -v "$command" >/dev/null || error "Bootstrap requires $command"; done
    { exec </dev/tty; } 2>/dev/null || error 'Run in an interactive terminal; sudo and AUR review need terminal input'
    [[ -t 0 && -t 1 ]] || error 'Run in an interactive terminal; sudo and AUR review need terminal input'
    parent=/tmp
    [[ ! -d /tmp/opencode ]] || parent=/tmp/opencode
    resources=$(mktemp -d "$parent/eco-linux-download.XXXXXXXX")
    trap 'rm -rf -- "$resources"' EXIT
    trap 'exit 130' INT
    trap 'exit 143' TERM
    git clone --depth 1 --branch master https://github.com/ecruzolivera/eco-linux.git "$resources/repo"
    [[ -f "$resources/repo/install.sh" && -f "$resources/repo/scripts/00-checks.sh" && -f "$resources/repo/lib/installer.sh" ]] || error 'Downloaded repository is not an eco-linux installer'
    revision=$(git -C "$resources/repo" rev-parse HEAD)
    info "Installing eco-linux revision $revision"
    bash "$resources/repo/install.sh"
    exit
  fi

  INSTALLER_DIR=$SCRIPT_DIR
  source "$INSTALLER_DIR/lib/installer.sh"
  if [[ ${ECO_REMOTE_SESSION:-0} == 1 || -n ${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} ]]; then
    ECO_REMOTE_SESSION=1
  else
    ECO_REMOTE_SESSION=0
  fi
  if [[ $(id -u) -ne 0 ]]; then
    command -v sudo >/dev/null || error 'Install sudo and create a sudo-capable normal user first'
    exec sudo env "ECO_REMOTE_SESSION=$ECO_REMOTE_SESSION" bash "$INSTALLER_DIR/install.sh"
  fi
  installer_defaults

  CURRENT_MODULE=preflight
  INSTALL_COMPLETE=0
  trap 'code=$?; if (( ! INSTALL_COMPLETE )); then warn "Installation incomplete in $CURRENT_MODULE (exit $code). No temporary sudo grants were created."; fi' EXIT
  trap 'warn "Failure in $CURRENT_MODULE at line $LINENO"' ERR
  trap 'exit 130' INT
  trap 'exit 143' TERM
  for group in SYS_CONFIG XDG_CONFIG HOME_ROOT_CONFIG LOCAL_BIN LOCAL_SHARE; do
    case $group in
      SYS_CONFIG) directory=system-config;; XDG_CONFIG) directory=xdg-config;;
      HOME_ROOT_CONFIG) directory=home-root-config;; LOCAL_BIN) directory=local-bin;;
      LOCAL_SHARE) directory=local-share;;
    esac
    printf -v "INSTALLER_${group}_DIR" '%s' "$INSTALLER_DIR/$directory"
  done
  for module in "$INSTALLER_DIR"/scripts/*.sh; do
    CURRENT_MODULE=${module##*/}
    info "Running $CURRENT_MODULE"
    source "$module"
  done
  INSTALL_COMPLETE=1
}

main "$@"
