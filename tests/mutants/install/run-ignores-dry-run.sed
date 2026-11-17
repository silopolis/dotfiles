# run() of the shared helper executes the command whether or not CHEZMOI_SCRIPTS_DRY_RUN is set
/^run() {/,/^}/ s/if dry_run; then/if false; then/
