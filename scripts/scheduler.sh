#!/bin/bash
# =============================================================
# scheduler.sh - Sets up cron job for automated audit execution
# =============================================================

# Always resolve utility to where the script actually is
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/utils.sh"

PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# -------------------------------------------------------------
# VARIABLES
# -------------------------------------------------------------
# absolute path to auto_audit.sh — cron needs full paths, not relative
SCRIPT_PATH="$SCRIPT_DIR/auto_audit.sh"
CRON_LOG="$PROJECT_ROOT/logs/cron.log"

# run auto_audit.sh every day at 4:00 AM
# auto_audit.sh collects info, generates report, and sends it by email silently
CRON_JOB="0 4 * * * bash $SCRIPT_PATH >> $CRON_LOG 2>&1"

# -------------------------------------------------------------
# SETUP CRON JOB
# -------------------------------------------------------------
setup_cron() {
    print_section "CRON JOB SETUP"
    log_info "Setting up cron job..."

    if ! check_command crontab; then
        log_error "crontab not found. Cannot set up cron job."
        return 1
    fi

    if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_warn "Cron job already exists. Skipping."
        return 0
    fi

    # crontab -l might fail completely if no crontab exists (returns 1 on many systems)
    # The subshell structure handles this gracefully.
    (crontab -l 2>/dev/null || true; echo "$CRON_JOB") | crontab -
    
    # check if it was added successfully by searching for it
    if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_info "Cron job set up successfully."
        log_info "Audit will run every day at 4:00 AM."
        log_info "Logs will be saved to: $CRON_LOG"
    else
        log_error "Failed to set up cron job."
        return 1
    fi
}

# -------------------------------------------------------------
# REMOVE CRON JOB
# -------------------------------------------------------------
remove_cron() {
    print_section "REMOVE CRON JOB"
    log_info "Removing cron job..."

    if ! crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_warn "No cron job found. Nothing to remove."
        return 0
    fi

    # filter out the line and rewrite crontab
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -

    # verify
    if ! crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_info "Cron job removed successfully."
    else
        log_error "Failed to remove cron job."
        return 1
    fi
}

# -------------------------------------------------------------
# SHOW CRON JOB STATUS
# -------------------------------------------------------------
show_cron_status() {
    print_section "CRON JOB STATUS"

    if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_info "Cron job is ACTIVE."
        log_info "Schedule: every day at 4:00 AM"
        log_info "Log file: $CRON_LOG"
    else
        log_warn "Cron job is NOT set up."
    fi
}


# Enforce arguments
if [[ $# -eq 0 ]]; then
    echo "Usage: bash scheduler.sh [setup|remove|status]"
    exit 1
fi

# -------------------------------------------------------------
# MAIN
# -------------------------------------------------------------
case "$1" in
    setup)
        setup_cron
        ;;
    remove)
        remove_cron
        ;;
    status)
        show_cron_status
        ;;
    *)
        echo "Usage: bash scheduler.sh [setup|remove|status]"
        ;;
esac