#!/bin/bash
set -euo pipefail

VERSION="1.0.0"
CACHE_DIR="/tmp/eco-linux"
REPO="https://github.com/ecruzolivera/eco-linux"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
error() {
  echo -e "  ${RED}✗${NC} $1"
  exit 1
}
phase() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        eco-linux v$VERSION Installer   ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

if [ ! -f "lib/00-checks.sh" ]; then
  echo "Downloading eco-linux resources..."
  rm -rf "$CACHE_DIR"
  mkdir -p "$CACHE_DIR"
  curl -fsSL "$REPO/archive/refs/heads/master.tar.gz" | tar -xz -C "$CACHE_DIR" --strip-components=1
  cd "$CACHE_DIR"
fi

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash install.sh
fi

for module in lib/*.sh; do
  source "$module"
done

main() {
  do_checks
  do_system
  do_yay
  do_official_packages
  do_aur_packages
  do_zsh
  do_nvidia
  do_niri
  do_noctalia
  do_sddm
  do_configs
  do_final
}

main
