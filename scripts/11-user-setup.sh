phase 'Normal-user bootstrap'
if [[ $ECO_SKIP_USER_SETUP == 1 ]]; then
  warn 'User bootstrap skipped: runtimes/editor/integrations remain incomplete'
  return
fi
run_user env "ECO_APPS=$ECO_APPS" bash "$INSTALLER_DIR/lib/user-setup.sh" "$INSTALLER_DIR"
