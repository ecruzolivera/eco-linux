phase 'Networking and Docker'
if [[ $ECO_NETWORK == networkmanager ]]; then
  # Recheck after package installation; never replace a newly started manager.
  current_network=$(select_network)
  if [[ $current_network == networkmanager ]]; then
    systemctl enable NetworkManager
    info 'NetworkManager enabled for the next boot; current connectivity left intact'
  else
    info 'Network manager detected during installation; preserving it'
  fi
else
  info 'Existing network/DNS services and resolv.conf preserved'
fi
mkdir -p /etc/docker
if [[ -e /etc/docker/daemon.json ]]; then
  info 'Existing Docker daemon configuration preserved'
else
  # Docker chooses its standard network and upstream DNS; no host stub listener,
  # hard-coded subnet or machine-specific systemd-resolved dependency.
  cat > /etc/docker/daemon.json <<'EOF'
{
  "log-driver": "json-file",
  "log-opts": { "max-size": "10m", "max-file": "5" }
}
EOF
fi
systemctl enable docker.socket
usermod -aG docker "$REAL_USER"
warn 'Docker group membership grants root-equivalent access; effective after a fresh login'
