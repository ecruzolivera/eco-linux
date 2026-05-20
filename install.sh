#!/bin/bash
set -euo pipefail

REPO="https://github.com/ecruzolivera/eco-linux"
VERSION="1.0.0"
INSTALLER_DIR="/tmp/eco-linux"
INSTALLER_SYS_CONFIG_DIR="$INSTALLER_DIR/system-config"
INSTALLER_XDG_CONFIG_DIR="$INSTALLER_DIR/xdg-config"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${RED}Red${NC}"
echo -e "${GREEN}Green${NC}"
echo -e "${YELLOW}Yellow${NC}"
echo -e "${CYAN}Cyan${NC}"
echo -e "${BOLD}Bold${NC}"

info() { echo -e "  ${GREEN}✓${NC} $1"; }
warn() { echo -e "  ${YELLOW}⚠${NC} $1"; }
error() {
  echo -e "  ${RED}✗${NC} $1"
  exit 1
}
phase() { echo -e "\n${CYAN}━━━ $1 ━━━${NC}"; }

info "VERSION: $VERSION"
info "Installer directory: $INSTALLER_DIR"
info "Installer system config: $INSTALLER_SYS_CONFIG_DIR"
info "Installer xdg config: $INSTALLER_XDG_CONFIG_DIR"

echo -e "${CYAN}╔══════════════════════════════════════╗${NC}"
echo -e "${CYAN}║        eco-linux v$VERSION Installer ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════╝${NC}"

if [ ! -f "lib/00-checks.sh" ]; then
  info "Downloading eco-linux resources..."
  sudo rm -rf "$INSTALLER_DIR"
  mkdir -p "$INSTALLER_DIR"
  curl -fsSL "$REPO/archive/refs/heads/master.tar.gz" | tar -xz -C "$INSTALLER_DIR" --strip-components=1
  cd "$INSTALLER_DIR"
fi

if [ "$(id -u)" -ne 0 ]; then
  exec sudo bash install.sh
fi

for module in scripts/*.sh; do
  info "Running module: $module"
  source "$module"
done
