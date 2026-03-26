#!/usr/bin/env bash

set -euo pipefail

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

# Load email config — the file defines RECIPIENT_EMAIL and SENDER_EMAIL
if [[ -f "$PROJECT_ROOT/config/email.conf" ]]; then
    source "$PROJECT_ROOT/config/email.conf"
else
    # Provide safe defaults so the script doesn't crash with set -u
    RECIPIENT_EMAIL="admin@example.com"
    SENDER_EMAIL="audit@example.com"
fi

if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="$PROJECT_ROOT/reports"
fi

# Check which email tool is available on this machine
detect_mail_tool() {
    if command -v msmtp &>/dev/null; then
        echo "msmtp"
    elif command -v sendmail &>/dev/null; then
        echo "sendmail"
    elif command -v mail &>/dev/null; then
        echo "mail"
    else
        echo "none"
    fi
}

get_latest_report() {
    # ls -t sorts newest first — || true so it doesn't crash when the dir is empty
    ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -1 || true
}

send_report() {
    echo -e "${CYAN}${BOLD}  [ Email Report Sender ]${RESET}"
    echo ""

    local mail_tool
    mail_tool=$(detect_mail_tool)

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
            # || true prevents set -e from dying when ls finds no files
            report_file=$(ls -t "$REPORT_DIR"/short_report_*.txt 2>/dev/null | head -1 || true)
            ;;
        2)
            report_file=$(ls -t "$REPORT_DIR"/full_report_*.txt 2>/dev/null | head -1 || true)
            ;;
        3)
            report_file=$(ls -t "$REPORT_DIR"/full_report_*.html 2>/dev/null | head -1 || true)
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${RESET}"
            return 1
            ;;
    esac

    if [[ -z "$report_file" || ! -f "$report_file" ]]; then
        echo -e "  ${RED}[ERROR] No report found. Generate a report first.${RESET}"
        echo ""
        return 1
    fi

    echo -e "  ${GREEN}Report file found:${RESET} $report_file"
    echo ""

    echo -e "  ${YELLOW}Sending to:${RESET} $RECIPIENT_EMAIL"
    echo -ne "  ${CYAN}Confirm? [y/n]: ${RESET}"
    read -r confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "  ${YELLOW}Email cancelled.${RESET}"
        echo ""
        return 0
    fi

    local subject="Linux Audit Report — $(hostname) — $(date '+%Y-%m-%d %H:%M')"
    echo -e "  ${YELLOW}Sending email...${RESET}"
    echo ""

    local send_ok=0

    if [[ "$mail_tool" == "msmtp" ]]; then
        {
            echo "To: $RECIPIENT_EMAIL"
            echo "From: $SENDER_EMAIL"
            echo "Subject: $subject"
            echo ""
            cat "$report_file"
        } | msmtp "$RECIPIENT_EMAIL" && send_ok=1 || send_ok=0

    elif [[ "$mail_tool" == "sendmail" ]]; then
        {
            echo "To: $RECIPIENT_EMAIL"
            echo "Subject: $subject"
            echo ""
            cat "$report_file"
        } | sendmail -v "$RECIPIENT_EMAIL" && send_ok=1 || send_ok=0

    elif [[ "$mail_tool" == "mail" ]]; then
        # -a is the portable attachment flag for most mail implementations
        # If you're on mailutils use -A, on bsd-mailx use -a
        mail -s "$subject" -a "$report_file" "$RECIPIENT_EMAIL" < /dev/null && send_ok=1 || send_ok=0
    fi

    if [[ "$send_ok" -eq 1 ]]; then
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