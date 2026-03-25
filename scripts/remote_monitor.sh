#!/usr/bin/env bash

# -e Stop the script if any command fails
# -u Stop if you use a variable you forgot to define
# -o pipefail Stop if a command inside a pipe | fails
set -euo pipefail

# Find where THIS script is, works on all machines
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Go one folder up = the project root
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# If utils.sh exists load it, if not define colors manually
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

# Load audit config to know where reports are saved
if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="/var/log/sys_audit"
fi

# Check if SSH is available
check_ssh() {
    # command -v ssh checks if ssh is installed
    if ! command -v ssh &>/dev/null; then
        echo -e "  ${RED}[ERROR] SSH is not installed on this machine.${RESET}"
        echo -e "  ${YELLOW}Install it using: sudo apt install openssh-client${RESET}"
        echo ""
        return 1
    fi
}

# FUNCTION: Test the SSH connection
# before trying to do anything on the remote machine
test_ssh_connection() {
    # $1 = the remote user example root
    # $2 = the remote host IP 
    local remote_user="$1"
    local remote_host="$2"

    echo -e "  ${YELLOW}Testing SSH connection to ${remote_user}@${remote_host}...${RESET}"

    # ssh -q quiet mode, no banner messages
    # -o ConnectTimeout=5  stop trying after 5 seconds
    # -o BatchMode=yes  dont ask for password (uses key only)
    # "exit"  just connect and immediately exit, dont run anything
    if ssh -q -o ConnectTimeout=5 -o BatchMode=yes \
        "${remote_user}@${remote_host}" "exit" 2>/dev/null; then
        echo -e "  ${GREEN}✔  Connection successful.${RESET}"
        echo ""
        return 0
    else
        echo -e "  ${RED}[ERROR] Cannot connect to ${remote_user}@${remote_host}.${RESET}"
        echo ""
        return 1
    fi
}

# Get live system info from the remote machine via SSH
monitor_remote() {
    local remote_user="$1"
    local remote_host="$2"

    echo -e "${CYAN}${BOLD}  [ Remote Machine: ${remote_user}@${remote_host} ]${RESET}"
    echo ""

    # ssh runs all these commands on the REMOTE machine
    # everything inside ' ' is executed there, not here
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
# top -bn1 runs once, grep finds CPU line
top -bn1 | grep "Cpu(s)" | awk '{print "  " $0}'
echo ""

echo "--- MEMORY ---"
# free -h shows memory in human readable format
free -h | awk '/^Mem:/ {print "  Total: " $2 " | Used: " $3 " | Free: " $4}'
echo ""

echo "--- DISK USAGE ---"
# df -h shows disk space
df -h | awk 'NR>1 {print "  " $1 " → " $5 " used"}'
echo ""

echo "--- LOGGED IN USERS ---"
# who shows who is currently logged in
who | awk '{print "  " $0}'
echo ""

echo "--- TOP 5 PROCESSES ---"
# ps aux sorted by CPU, top 5
ps aux --sort=-%cpu | head -6 | awk '{print "  " $0}'
echo ""

echo "--- OPEN PORTS ---"
# ss -tuln shows all listening ports
ss -tuln | awk '{print "  " $0}'
echo ""

echo "======================================"
echo "  END OF REMOTE REPORT"
echo "======================================"

REMOTE_COMMANDS

}

# Send our local report to the remote server using scp
send_report_to_remote() {
    local remote_user="$1"
    local remote_host="$2"

    local latest_report
    latest_report=$(ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -1)

    # If no report exists yet show error
    # -z checks if the variable is empty true if the varialble is empty, -f checks if the file exists
    if [[ -z "$latest_report" ]]; then
        echo -e "  ${RED}[ERROR] No local report found. Generate a report first.${RESET}"
        echo ""
        return 1
    fi

    echo -e "  ${YELLOW}Sending report to remote server...${RESET}"
    echo -e "  ${YELLOW}File: $latest_report${RESET}"
    echo ""

    # scp = secure copy — copies a file over SSH
    # -o ConnectTimeout=10 → stop after 10 seconds if no connection
    # The destination is: user@host:/path/on/remote/machine
    if scp -o ConnectTimeout=10 "$latest_report" \
        "${remote_user}@${remote_host}:/tmp/audit_reports/"; then
        echo -e "  ${GREEN}✔  Report sent to ${remote_user}@${remote_host}:/tmp/audit_reports/${RESET}"

        local log_file="$REPORT_DIR/remote_log.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Report sent to ${remote_user}@${remote_host} | File: $latest_report" >> "$log_file"
        echo -e "  ${YELLOW}Logged to: $log_file${RESET}"
    else
        echo -e "  ${RED}[ERROR] Failed to send report.${RESET}"
        echo -e "  ${YELLOW}Check SSH connection and permissions on the remote server.${RESET}"
    fi
    echo ""
}

# Main remote monitor menu
# This is what gets called from main.sh
remote_monitor() {

    echo -e "${CYAN}${BOLD}  [ Remote Monitoring via SSH ]${RESET}"
    echo ""

    check_ssh || return 1
    echo -ne "  ${CYAN}Enter remote username: ${RESET}"
    read -r remote_user

    echo -ne "  ${CYAN}Enter remote host IP : ${RESET}"
    read -r remote_host

    # make sure user didn't leave fields empty
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
            # Only monitor the remote machine
            monitor_remote "$remote_user" "$remote_host"
            ;;
        2)
            # Only send the report to remote server
            send_report_to_remote "$remote_user" "$remote_host"
            ;;
        3)
            # Do both: monitor then send
            monitor_remote "$remote_user" "$remote_host"
            send_report_to_remote "$remote_user" "$remote_host"
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${RESET}"
            return 1
            ;;
    esac
}