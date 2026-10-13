#!/bin/bash
set -Eeuo pipefail

info() { printf '  ✓ %s\n' "$*"; }
warn() { printf '  ⚠ %s\n' "$*" >&2; }
error() { printf '  ✗ %s\n' "$*" >&2; exit 1; }
phase() { printf '\n━━━ %s ━━━\n' "$*"; }

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)
# A standalone download must select a revision; a local checkout uses itself.
if [[ ! -f "$SCRIPT_DIR/scripts/00-checks.sh" ]]; then
  if [[ ${1:-} == --help ]]; then
    printf 'Standalone bootstrap: bash install.sh --ref <tag-or-commit> [installer options]\n'
    exit 0
  fi
  [[ ${1:-} == --ref && ${2:-} =~ ^[A-Za-z0-9._-]+$ ]] || error 'Standalone bootstrap requires --ref <tag-or-commit> (not an implicit master download)'
  [[ $(id -u) != 0 ]] || error 'Run the standalone bootstrap as your normal user without sudo; it escalates itself'
  ref=$2
  shift 2
  for command in curl tar mktemp sudo; do command -v "$command" >/dev/null || error "Bootstrap requires $command"; done
  parent=/tmp
  [[ ! -d /tmp/opencode ]] || parent=/tmp/opencode
  resources=$(mktemp -d "$parent/eco-linux-download.XXXXXXXX")
  trap 'rm -rf -- "$resources"' EXIT
  curl --fail --location --proto '=https' --tlsv1.2 "https://github.com/ecruzolivera/eco-linux/archive/$ref.tar.gz" -o "$resources/source.tar.gz"
  tar -xzf "$resources/source.tar.gz" -C "$resources" --strip-components=1
  [[ -f "$resources/scripts/00-checks.sh" ]] || error 'Downloaded revision is not an eco-linux installer'
  bash "$resources/install.sh" "$@"
  exit
fi

INSTALLER_DIR=$SCRIPT_DIR
source "$INSTALLER_DIR/lib/installer.sh"
parse_options "$@"
if [[ $ECO_FIREWALL == enable && -n ${SSH_CONNECTION:-}${SSH_CLIENT:-}${SSH_TTY:-} ]]; then
  error 'Use --firewall preserve for a remote SSH installation'
fi
if [[ $(id -u) -ne 0 ]]; then
  command -v sudo >/dev/null || error 'Install sudo and create a sudo-capable normal user first'
  exec sudo bash "$INSTALLER_DIR/install.sh" "$@"
fi

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
