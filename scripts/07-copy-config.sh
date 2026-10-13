# Deployment only: no package installation, authentication or service startup.
for legacy in "$USER_CONFIG/opencode/opencode.json" "$REAL_HOME/.zshenv" "$USER_CONFIG/opencode/skills"; do
  if [[ -e $legacy || -L $legacy ]]; then warn "Legacy path preserved: $legacy (review manually)"; fi
done
phase 'Deploy user configuration'
copy_repo=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd -P)
copy_environment=(
  "REAL_HOME=$REAL_HOME" "USER_CONFIG=$USER_CONFIG"
  "INSTALLER_XDG_CONFIG_DIR=$INSTALLER_XDG_CONFIG_DIR"
  "INSTALLER_HOME_ROOT_CONFIG_DIR=$INSTALLER_HOME_ROOT_CONFIG_DIR"
  "INSTALLER_LOCAL_BIN_DIR=$INSTALLER_LOCAL_BIN_DIR"
  "INSTALLER_LOCAL_SHARE_DIR=$INSTALLER_LOCAL_SHARE_DIR"
  "ECO_PROFILE=${ECO_PROFILE:-portable}" "ECO_CONFIG_MODE=${ECO_CONFIG_MODE:-replace}"
)
if declare -F run_user >/dev/null; then
  run_user env "${copy_environment[@]}" /usr/bin/python3 "$copy_repo/lib/deploy-config.py"
else
  env "${copy_environment[@]}" /usr/bin/python3 "$copy_repo/lib/deploy-config.py"
fi
