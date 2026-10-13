phase 'Normal-user bootstrap'
run_user env "ECO_APPS=$ECO_APPS" bash "$INSTALLER_DIR/lib/user-setup.sh" "$INSTALLER_DIR"
