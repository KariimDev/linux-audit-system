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

# Load missing variables with safe fallbacks
EMAIL_RECIPIENT="admin@example.com"
EMAIL_SENDER="audit@example.com"
SMTP_USER="audit@example.com"
SMTP_PASSWORD="none"
SMTP_HOST="smtp.gmail.com"
SMTP_PORT="587"

if [[ -f "$PROJECT_ROOT/config/email.conf" ]]; then
    source "$PROJECT_ROOT/config/email.conf"
fi

if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="$PROJECT_ROOT/reports"
fi

detect_mail_tool() {
    if command -v msmtp &>/dev/null; then
        echo "msmtp"
    elif command -v mail &>/dev/null; then
        echo "mail"
    elif command -v sendmail &>/dev/null; then
        echo "sendmail"
    else
        echo "none"
    fi
}

get_latest_report() {
    ls -t "$REPORT_DIR"/*.txt 2>/dev/null | head -1 || true
}

# Core email sending engine that directly uses your email.conf passwords!
execute_email_send() {
    local report_file="$1"
    local subject="Linux Audit Report — $(hostname) — $(date '+%Y-%m-%d %H:%M')"
    local content_type="text/plain; charset=utf-8"
    if [[ "$report_file" == *.html ]]; then
        content_type="text/html; charset=utf-8"
    fi
    local mail_tool
    mail_tool=$(detect_mail_tool)
    local send_ok=0

    echo -e "  ${YELLOW}Sending email via $mail_tool...${RESET}"
    echo ""

    if [[ "$mail_tool" == "none" ]]; then
        echo -e "  ${RED}[ERROR] No email tool found on this Linux machine.${RESET}"
        echo -e "  ${YELLOW}Please install one: sudo apt install msmtp${RESET}"
        return 1
    fi

    if [[ "$mail_tool" == "msmtp" ]]; then
        # Create a dynamic, temporary configuration file using the email.conf variables
        local temp_conf="/tmp/audit_msmtp_$$.conf"
        {
            echo "defaults"
            echo "auth on"
            echo "tls on"
            echo "tls_certcheck off"
            echo "account default"
            echo "host $SMTP_HOST"
            echo "port $SMTP_PORT"
            echo "from $EMAIL_SENDER"
            echo "user $SMTP_USER"
            echo "password $SMTP_PASSWORD"
        } > "$temp_conf"
        # Root only read/write (REQUIRED by msmtp security)
        chmod 600 "$temp_conf"

        # Pipe the email and force msmtp to use the custom config file (-C)
        {
            echo "To: $EMAIL_RECIPIENT"
            echo "From: $EMAIL_SENDER"
            echo "Subject: $subject"
            echo "MIME-Version: 1.0"
            echo "Content-Type: $content_type"
            echo ""
            cat "$report_file"
        } | msmtp -C "$temp_conf" "$EMAIL_RECIPIENT" && send_ok=1 || send_ok=0

        # Always delete the temporary password file securely
        rm -f "$temp_conf"

    elif [[ "$mail_tool" == "mail" ]]; then
        # Use Heirloom mailx dynamic remote SMTP flags
        mail -v -s "$subject" \
             -S smtp="smtp://$SMTP_HOST:$SMTP_PORT" \
             -S smtp-use-starttls \
             -S smtp-auth=login \
             -S smtp-auth-user="$SMTP_USER" \
             -S smtp-auth-password="$SMTP_PASSWORD" \
             -S from="$EMAIL_SENDER" \
             -a "$report_file" \
             "$EMAIL_RECIPIENT" < /dev/null && send_ok=1 || send_ok=0

    elif [[ "$mail_tool" == "sendmail" ]]; then
        # sendmail doesn't easily accept remote passwords via command line,
        # it relies on local postfix/exim configurations. We attempt a blind send.
        {
            echo "To: $EMAIL_RECIPIENT"
            echo "From: $EMAIL_SENDER"
            echo "Subject: $subject"
            echo "MIME-Version: 1.0"
            echo "Content-Type: $content_type"
            echo ""
            cat "$report_file"
        } | sendmail -v "$EMAIL_RECIPIENT" && send_ok=1 || send_ok=0
    fi

    if [[ "$send_ok" -eq 1 ]]; then
        echo -e "  ${GREEN}✔  Email sent successfully to: $EMAIL_RECIPIENT${RESET}"
        local log_file="$REPORT_DIR/email_log.txt"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Email sent to $EMAIL_RECIPIENT | File: $report_file" >> "$log_file" || true
    else
        echo -e "  ${RED}[ERROR] Failed to send email.${RESET}"
        echo -e "  ${YELLOW}Double-check your credentials in config/email.conf${RESET}"
    fi
}

# Interactive Menu function
send_report() {
    echo -e "${CYAN}${BOLD}  [ Email Report Sender ]${RESET}"
    echo ""

    if [[ "$(detect_mail_tool)" == "none" ]]; then
        echo -e "  ${RED}[ERROR] No email tool found. Install msmtp.${RESET}"
        return 1
    fi

    echo -e "  ${YELLOW}Which report do you want to send?${RESET}"
    echo -e "  ${GREEN}[1]${RESET} Short Report (.txt)"
    echo -e "  ${GREEN}[2]${RESET} Full Report  (.txt)"
    echo -e "  ${GREEN}[3]${RESET} Full Report  (.html)"
    echo ""
    echo -ne "  ${CYAN}Enter your choice [1-3]: ${RESET}"
    read -r report_choice

    local report_file=""
    case "$report_choice" in
        1) report_file=$(ls -t "$REPORT_DIR"/short_report_*.txt 2>/dev/null | head -1 || true) ;;
        2) report_file=$(ls -t "$REPORT_DIR"/full_report_*.txt 2>/dev/null | head -1 || true) ;;
        3) report_file=$(ls -t "$REPORT_DIR"/full_report_*.html 2>/dev/null | head -1 || true) ;;
        *) echo -e "  ${RED}Invalid choice.${RESET}"; return 1 ;;
    esac

    if [[ -z "$report_file" || ! -f "$report_file" ]]; then
        echo -e "  ${RED}[ERROR] No report found. Generate a report first.${RESET}"
        echo ""
        return 1
    fi

    echo -e "  ${GREEN}Report file found:${RESET} $report_file"
    echo -e "  ${YELLOW}Sending to:${RESET} $EMAIL_RECIPIENT"
    echo -ne "  ${CYAN}Confirm? [y/n]: ${RESET}"
    read -r confirm

    if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
        echo -e "  ${YELLOW}Email cancelled.${RESET}"
        return 0
    fi

    execute_email_send "$report_file"
    echo ""
}

# Fully automated version for the auto_audit.sh cron job!
send_report_auto() {
    local report_file
    # Grabs the newest full txt report
    report_file=$(ls -t "$REPORT_DIR"/full_report_*.txt 2>/dev/null | head -1 || true)

    if [[ -z "$report_file" || ! -f "$report_file" ]]; then
        log_error "Auto-email failed: No full report found in $REPORT_DIR"
        return 1
    fi

    log_info "Auto-emailing $report_file to $EMAIL_RECIPIENT"
    execute_email_send "$report_file" >/dev/null 2>&1 || log_error "Auto-email execution failed."
}