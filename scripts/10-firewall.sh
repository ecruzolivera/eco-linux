phase 'Firewall'
[[ $ECO_FIREWALL == enable ]] || { info 'Firewall configuration preserved'; return; }
if ufw status | grep -q 'Status: active'; then
  info 'Existing active UFW policy preserved'
else
  ufw default deny incoming
  ufw default allow outgoing
  ufw allow 53317/udp
  ufw allow 53317/tcp
  ufw --force enable
fi
systemctl enable ufw
ufw-docker install
ufw reload
