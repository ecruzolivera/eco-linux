# 10-final.sh — Service enablement and reboot prompt

do_final() {
  phase "Final Setup"

  info "Enabling SDDM..."
  systemctl enable sddm

  info "Enabling PipeWire user services..."
  systemctl --global enable pipewire.service pipewire-pulse.service wireplumber.service

  info "Adding $REAL_USER to relevant groups..."
  usermod -aG audio,video,input "$REAL_USER" 2>/dev/null || true

  info ""
  echo -e "  ${GREEN}eco-linux installation complete!${NC}"
  echo ""
  echo -e "  ${CYAN}Summary:${NC}"
  echo -e "  • WM:        ${BOLD}niri${NC} + ${BOLD}Noctalia Shell${NC}"
  echo -e "  • Terminal:  ${BOLD}ghostty${NC}"
  echo -e "  • Browser:   ${BOLD}Firefox Dev${NC} + ${BOLD}Brave${NC}"
  echo -e "  • File mgr:  ${BOLD}yazi${NC} + ${BOLD}nautilus${NC}"
  echo -e "  • CLI tools: ${BOLD}gh${NC}, ${BOLD}glab${NC}, ${BOLD}neovim${NC}"
  echo -e "  • Media:     ${BOLD}mpv${NC}, ${BOLD}steam${NC}"
  echo -e "  • Other:     ${BOLD}Bitwarden${NC}, ${BOLD}LocalSend${NC}"
  echo -e "  • Login:     ${BOLD}SDDM${NC} (autologin for $REAL_USER)"
  echo ""
  echo -e "  ${YELLOW}After reboot, Noctalia Shell will start automatically.${NC}"
  echo -e "  ${YELLOW}The polkit-agent plugin will be downloaded on first launch.${NC}"
  echo ""

  info "Reboot when ready: sudo systemctl reboot"
}
