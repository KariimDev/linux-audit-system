#!/bin/bash
# auto_audit.sh - Runs automatically by cron
# Collects hardware and software info, generates a full report, and sends it by email
# No interaction needed — fully silent and automated

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

source "$SCRIPT_DIR/utils.sh"
source "$SCRIPT_DIR/hardware_audit.sh"
source "$SCRIPT_DIR/software_audit.sh"
source "$SCRIPT_DIR/report_generator.sh"
source "$SCRIPT_DIR/email_sender.sh"

log_info "Automated audit started."

hardware_audit
software_audit
generate_full_report
send_report_auto

log_info "Automated audit finished."
