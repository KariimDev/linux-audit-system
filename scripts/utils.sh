#!/bin/bash
# utils.sh - Shared utility functions for the audit system
# Author: Karim

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
RESET='\033[0m'

# Use absolute path so logging works no matter where the script is called from
# BASH_SOURCE[0] is utils.sh itself, so we go up two levels: scripts/ -> project root -> logs/
_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="$(dirname "$_UTILS_DIR")/logs"
LOG_FILE="$LOG_DIR/audit.log"

# Make sure the logs directory actually exists before anyone tries to write to it
mkdir -p "$LOG_DIR"

log_info() {
    echo -e "${GREEN}[INFO]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

log_error() {
    echo -e "${RED}[ERROR]${RESET} $(timestamp) - $1" | tee -a "$LOG_FILE"
}

timestamp() {
    if ! command -v date &>/dev/null; then
        echo "N/A"
        return 1
    fi
    date +"%Y-%m-%d %H:%M:%S"
}

check_command() {
    if ! command -v "$1" &>/dev/null; then
        log_warn "Command '$1' not found — skipping."
        return 1
    fi
    return 0
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_warn "Not running as root. Some information may be unavailable."
    fi
}

print_section() {
    echo -e "\n${BOLD}${BLUE}===== $1 =====${RESET}\n"
}

separator() {
    echo "============================================================"
}
