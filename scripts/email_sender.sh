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
 
# Load the email config file if it exists
# email.conf contains: RECIPIENT_EMAIL, SENDER_EMAIL, SMTP settings
if [[ -f "$PROJECT_ROOT/config/email.conf" ]]; then
    source "$PROJECT_ROOT/config/email.conf"
else
    
    RECIPIENT_EMAIL="admin@example.com"
    SENDER_EMAIL="audit@example.com"
fi
 
if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="/var/log/sys_audit"
fi
 
# Check which email tool is available
# Returns the tool name: msmtp, sendmail, or mail
detect_mail_tool() {
    # Check for msmtp if it is installed
    if command -v msmtp &>/dev/null; then
        echo "msmtp"
    # Check for sendmail if msmtp not found
    elif command -v sendmail &>/dev/null; then
        echo "sendmail"
    elif command -v mail &>/dev/null; then
        echo "mail"
    else
        echo "none"
    fi
}
 
get_latest_report() {
    # ls -t sorts by newest first
    # head -1 picks only the most recent file
    # 2>/dev/null hides errors if no files exist yet
    ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -1
}
 
send_report() {
 
    echo -e "${CYAN}${BOLD}  [ Email Report Sender ]${RESET}"
    echo ""
 
    local mail_tool
    mail_tool=$(detect_mail_tool)
 
    # If no email tool is found show error and stop
    if [[ "$mail_tool" == "none" ]]; then
        echo -e "  ${RED}[ERROR] No email tool found.${RESET}"
        echo -e "  ${YELLOW}Install one using:${RESET}"
        echo -e "    sudo apt install msmtp msmtp-mta"
        echo ""
        return 1
    fi
 
    echo -e "  ${GREEN}Email tool detected:${RESET} $mail_tool"
    echo ""
 
    echo -e "  ${YELLOW}Which report do you want to send?${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Short Report (.txt)"
    echo -e "  ${GREEN}[2]${RESET} Full Report  (.txt)"
    echo -e "  ${GREEN}[3]${RESET} Full Report  (.html)"
    echo ""
    echo -ne "  ${CYAN}Enter your choice [1-3]: ${RESET}"
    read -r report_choice
 
    local report_file=""
 
    case "$report_choice" in
        1)
            report_file=$(ls -t "$REPORT_DIR"/short_report_*.txt 2>/dev/null | head -1)
            ;;
        2)
            report_file=$(ls -t "$REPORT_DIR"/full_report_*.txt 2>/dev/null | head -1)
            ;;
        3)
            report_file=$(ls -t "$REPORT_DIR"/full_report_*.html 2>/dev/null | head -1)
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${RESET}"
            return 1
            ;;
    esac
 
 -- #-z checks if the variable is empty true if the varialble is empty, -f checks if the file exists
    if [[ -z "$report_file" || ! -f "$report_file" ]]; then
        echo -e "  ${RED}[ERROR] No report found. Generate a report first.${RESET}"
        echo ""
        return 1
    fi
 
    echo -e "  ${GREEN}Report file found:${RESET} $report_file"
    echo ""
 
    # Ask user to confirm the recipient email
    echo -e "  ${YELLOW}Sending to:${RESET} $RECIPIENT_EMAIL"
    echo -ne "  ${CYAN}Confirm? [y/n]: ${RESET}"
    read -r confirm
 
    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "  ${YELLOW}Email cancelled.${RESET}"
        echo ""
        return 0
    fi
 
    #Build email subject with hostname and date for better identification in inbox
    local subject="Linux Audit Report — $(hostname) — $(date '+%Y-%m-%d %H:%M')"
     echo -e "  ${YELLOW}Sending email...${RESET}"
    echo ""
 
    if [[ "$mail_tool" == "msmtp" ]]; then
        {
            echo "To: $RECIPIENT_EMAIL"
            echo "From: $SENDER_EMAIL"
            echo "Subject: $subject"
            echo ""
            cat "$report_file"
        } | msmtp "$RECIPIENT_EMAIL"
 
    elif [[ "$mail_tool" == "sendmail" ]]; then
        {
            echo "To: $RECIPIENT_EMAIL"
            echo "Subject: $subject"
            echo ""
            cat "$report_file"
        } | sendmail -v "$RECIPIENT_EMAIL"
 
    elif [[ "$mail_tool" == "mail" ]]; then
        mail -s "$subject" -A "$report_file" "$RECIPIENT_EMAIL" < /dev/null
    fi
 
    # $? is the exit code of the last command — 0 means success
    if [[ $? -eq 0 ]]; then
        echo -e "  ${GREEN}✔  Email sent successfully to: $RECIPIENT_EMAIL${RESET}"
 
        local log_file="$REPORT_DIR/email_log.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Email sent to $RECIPIENT_EMAIL | File: $report_file" >> "$log_file"
        echo -e "  ${YELLOW}Logged to: $log_file${RESET}"
    else
        echo -e "  ${RED}[ERROR] Failed to send email.${RESET}"
        echo -e "  ${YELLOW}Check your email configuration in config/email.conf${RESET}"
    fi
 
    echo ""
}
 