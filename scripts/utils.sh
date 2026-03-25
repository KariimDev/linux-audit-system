#!/bin/bash
# =============================================================
# utils.sh - Shared utility functions for the audit system
# Author: Karim
# Date: $(date)
# =============================================================

# -------------------------------------------------------------
# COLORS
# -------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# -------------------------------------------------------------
# LOGGING
# -------------------------------------------------------------
LOG_DIR="logs"
LOG_FILE="$LOG_DIR/audit.log"

log_info() {
    echo -e "${GREEN}[INFO]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

# -------------------------------------------------------------
# TIMESTAMP
# -------------------------------------------------------------
timestamp() {
    date +"%Y-%m-%d %H:%M:%S"
}

# -------------------------------------------------------------
# ERROR HANDLING
# -------------------------------------------------------------
check_command() {
    # Check if a command exists on the system
    if ! command -v "$1" &>/dev/null; then
        log_warn "Command '$1' not found — skipping."
        return 1
    fi
    return 0
}

check_root() {
    # Warn if script is not run as root (some commands need root)
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root. Some information may be unavailable."
    fi
}

# -------------------------------------------------------------
# SECTION HEADER (for reports)
# -------------------------------------------------------------
print_section() {
    echo -e "\n${BOLD}${BLUE}===== $1 =====${RESET}\n"
}

separator() {
    echo "============================================================"
}