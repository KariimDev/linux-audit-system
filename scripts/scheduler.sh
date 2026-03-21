#!/bin/bash
# =============================================================
# scheduler.sh - Sets up cron job for automated audit execution
# =============================================================
source "$(dirname "$0")/utils.sh"

# -------------------------------------------------------------
# VARIABLES
# -------------------------------------------------------------
# absolute path to main.sh — cron needs full paths, not relative
SCRIPT_PATH="$(cd "$(dirname "$0")" && pwd)/main.sh"
LOG_DIR="$(cd "$(dirname "$0")/../logs" && pwd)"
CRON_LOG="$LOG_DIR/cron.log"
# this is the cron job line — runs main.sh every day at 4:00 AM
CRON_JOB="0 4 * * * bash $SCRIPT_PATH >> $CRON_LOG 2>&1"

# -------------------------------------------------------------
# SETUP CRON JOB
# -------------------------------------------------------------
setup_cron() {
    print_section "CRON JOB SETUP"
    log_info "Setting up cron job..."

    # check if cron is available
    if ! check_command crontab; then
        log_error "crontab not found. Cannot set up cron job."
        return 1
    fi

    # check if cron job already exists to avoid duplicates
    # crontab -l lists current cron jobs
    # grep -F means fixed string, no regex
    # grep -q means quiet, no output, just return 0 or 1
    if crontab -l 2>/dev/null | grep -Fq "$SCRIPT_PATH"; then
        log_warn "Cron job already exists. Skipping."
        return 0
    fi

    # add the cron job
    # crontab -l gets existing jobs
    # echo adds our new job
    # | crontab - pipes everything back to crontab
    (crontab -l 2>/dev/null; echo "$CRON_JOB") | crontab -
    
    # check if it was added successfully
    if [ $? -eq 0 ]; then
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

    # grep -v means exclude lines matching the pattern
    # so we keep everything EXCEPT our cron job
    # then pipe back to crontab
    crontab -l 2>/dev/null | grep -v "$SCRIPT_PATH" | crontab -

    if [ $? -eq 0 ]; then
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