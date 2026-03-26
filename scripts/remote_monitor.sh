#!/usr/bin/env bash

# -e Stop the script if any command fails
# -u Stop if you use a variable you forgot to define
# -o pipefail Stop if a command inside a pipe fails
set -euo pipefail

# Find where THIS script is
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then
    source "$SCRIPT_DIR/utils.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
fi

# Load missing settings from config just in case
if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="$PROJECT_ROOT/reports"
    REMOTE_DIR="/tmp/audit_reports"
fi

check_ssh() {
    if ! command -v ssh &>/dev/null; then
        echo -e "  ${RED}[ERROR] SSH is not installed on this machine.${RESET}"
        echo -e "  ${YELLOW}Install it using: sudo apt install openssh-client${RESET}"
        echo ""
        return 1
    fi
}

test_ssh_connection() {
    local remote_user="$1"
    local remote_host="$2"

    echo -e "  ${YELLOW}Testing SSH connection to ${remote_user}@${remote_host}...${RESET}"

    # -q quiet mode
    # -o ConnectTimeout=5  stop trying after 5 seconds
    # -o BatchMode=yes  don't ask for a password prompt (requires SSH keys!)
    if ssh -q -o ConnectTimeout=5 -o BatchMode=yes \
        "${remote_user}@${remote_host}" "exit" 2>/dev/null; then
        echo -e "  ${GREEN}✔  Connection successful.${RESET}"
        echo ""
        return 0
    else
        echo -e "  ${RED}[ERROR] Cannot connect to ${remote_user}@${remote_host}.${RESET}"
        echo -e "  ${RED}Ensure SSH keys are configured (no password prompts allowed).${RESET}"
        echo ""
        return 1
    fi
}

monitor_remote() {
    local remote_user="$1"
    local remote_host="$2"

    echo -e "${CYAN}${BOLD}  [ Remote Machine: ${remote_user}@${remote_host} ]${RESET}"
    echo ""

    # Everything inside 'REMOTE_COMMANDS' runs on the remote machine
    ssh -o ConnectTimeout=10 "${remote_user}@${remote_host}" bash << 'REMOTE_COMMANDS'

echo "======================================"
echo "   REMOTE SYSTEM MONITOR"
echo "======================================"
echo "  Date     : $(date '+%A, %d %B %Y — %H:%M:%S')"
echo "  Hostname : $(hostname)"
echo "  User     : $(whoami)"
echo "======================================"
echo ""

echo "--- CPU USAGE ---"
# || true ensures we don't crash the remote connection process if the format differs
top -bn1 | grep -i "Cpu(s)" | awk '{print "  " $0}' || true
echo ""

echo "--- MEMORY ---"
free -h | awk '/^Mem:/ {print "  Total: " $2 " | Used: " $3 " | Free: " $4}'
echo ""

echo "--- DISK USAGE ---"
df -h | awk 'NR>1 {print "  " $1 " → " $5 " used"}'
echo ""

echo "--- LOGGED IN USERS ---"
who | awk '{print "  " $0}' || true
echo ""

echo "--- TOP 5 PROCESSES ---"
ps aux --sort=-%cpu | head -6 | awk '{print "  " $0}'
echo ""

echo "--- OPEN PORTS ---"
ss -tuln 2>/dev/null | awk '{print "  " $0}' || netstat -tuln 2>/dev/null | awk '{print "  " $0}' || true
echo ""

echo "======================================"
echo "  END OF REMOTE REPORT"
echo "======================================"

REMOTE_COMMANDS

}

send_report_to_remote() {
    local remote_user="$1"
    local remote_host="$2"

    local latest_report
    # || true so set -e doesn't kill execution if there are zero files
    latest_report=$(ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -1 || true)

    if [[ -z "$latest_report" || ! -f "$latest_report" ]]; then
        echo -e "  ${RED}[ERROR] No local report found. Generate a report first.${RESET}"
        echo ""
        return 1
    fi

    echo -e "  ${YELLOW}Sending report to remote server...${RESET}"
    echo -e "  ${YELLOW}File: $latest_report${RESET}"
    echo ""

    # Before SCPing, make sure the destination directory exists on the remote end
    ssh -q -o BatchMode=yes "${remote_user}@${remote_host}" "mkdir -p $REMOTE_DIR" 2>/dev/null || true

    # Using the directory defined in config/audit.conf (REMOTE_DIR) instead of hardcoding
    if scp -o ConnectTimeout=10 "$latest_report" \
        "${remote_user}@${remote_host}:${REMOTE_DIR}/"; then
        echo -e "  ${GREEN}✔  Report sent to ${remote_user}@${remote_host}:${REMOTE_DIR}/${RESET}"

        local log_file="$REPORT_DIR/remote_log.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Report sent to ${remote_user}@${remote_host} | File: $latest_report" >> "$log_file"
        echo -e "  ${YELLOW}Logged to: $log_file${RESET}"
    else
        echo -e "  ${RED}[ERROR] Failed to send report.${RESET}"
        echo -e "  ${YELLOW}Check SSH connection and permissions on the remote server.${RESET}"
    fi
    echo ""
}

remote_monitor() {
    echo -e "${CYAN}${BOLD}  [ Remote Monitoring via SSH ]${RESET}"
    echo ""

    check_ssh || return 1
    echo -ne "  ${CYAN}Enter remote username: ${RESET}"
    read -r remote_user

    echo -ne "  ${CYAN}Enter remote host IP : ${RESET}"
    read -r remote_host

    if [[ -z "$remote_user" || -z "$remote_host" ]]; then
        echo -e "  ${RED}[ERROR] Username and host cannot be empty.${RESET}"
        echo ""
        return 1
    fi

    echo ""

    test_ssh_connection "$remote_user" "$remote_host" || return 1

    echo -e "  ${YELLOW}What do you want to do?${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Monitor remote machine (live info)"
    echo -e "  ${GREEN}[2]${RESET} Send local report to remote server"
    echo -e "  ${GREEN}[3]${RESET} Both"
    echo ""
    echo -ne "  ${CYAN}Enter your choice [1-3]: ${RESET}"
    read -r action_choice

    echo ""

    case "$action_choice" in
        1)
            monitor_remote "$remote_user" "$remote_host"
            ;;
        2)
            send_report_to_remote "$remote_user" "$remote_host"
            ;;
        3)
            monitor_remote "$remote_user" "$remote_host"
            send_report_to_remote "$remote_user" "$remote_host"
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${RESET}"
            return 1
            ;;
    esac
}