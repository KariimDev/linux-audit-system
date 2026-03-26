#!/usr/bin/env bash

# -e  exit on error
# -u  exit on unbound variable
# -o pipefail  exit if any command in a pipe fails
set -euo pipefail

# BASH_SOURCE[0] points to main.sh itself, so this always resolves correctly
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

print_banner() {
    clear
    # switch ON cyan + bold color — like a switch on/off for colors
    echo -e "${CYAN}${BOLD}"
    echo "  ================================================"
    echo "       Linux System Audit & Monitoring Tool"
    echo "       NSCS — Academic Year 2025/2026"
    echo "  ================================================"
    # switch OFF all colors
    echo -e "${RESET}"
    echo -e "${YELLOW}   $(date '+%A, %d %B %Y — %H:%M:%S')${RESET}"
    echo ""
}

print_menu() {
    echo -e "${CYAN}${BOLD}  Select an option:${RESET}"
    echo ""
    echo -e "  ${GREEN}[1]${RESET} Hardware Audit"
    echo -e "  ${GREEN}[2]${RESET} Software & OS Audit"
    echo -e "  ${GREEN}[3]${RESET} Generate Short Report"
    echo -e "  ${GREEN}[4]${RESET} Generate Full Report"
    echo -e "  ${GREEN}[5]${RESET} Send Report via Email"
    echo -e "  ${GREEN}[6]${RESET} Remote Monitoring (SSH)"
    echo -e "  ${YELLOW}[7]${RESET} Compare Two Reports  ★ Bonus"
    echo -e "  ${YELLOW}[8]${RESET} CPU Alert Check      ★ Bonus"
    echo -e "  ${YELLOW}[9]${RESET} Verify Log Integrity ★ Bonus"
    echo -e "  ${RED}[0]${RESET} Exit"
    echo ""
}

# Pause and wait for the user to press Enter
press_enter() {
    echo ""
    echo -e "  ${YELLOW}Press Enter to return to the menu...${RESET}"
    read -r
}

# Load hardware_audit.sh and software_audit.sh once at startup
# Sourcing inside the loop every iteration was wasteful and could cause side effects
load_modules() {
    local modules=("hardware_audit.sh" "software_audit.sh")
    for module in "${modules[@]}"; do
        if [[ -f "$SCRIPT_DIR/$module" ]]; then
            source "$SCRIPT_DIR/$module"
        else
            echo -e "${RED}  error: missing module: $module${RESET}"
        fi
    done
}

# Source all other scripts once up front as well — NOT inside the menu loop
# This avoids re-running global setup code (mkdir, config loading) on every keypress
load_optional_modules() {
    local optional=("report_generator.sh" "email_sender.sh" "remote_monitor.sh")
    for module in "${optional[@]}"; do
        if [[ -f "$SCRIPT_DIR/$module" ]]; then
            source "$SCRIPT_DIR/$module"
        else
            echo -e "${RED}  warning: optional module missing: $module${RESET}"
        fi
    done
}

main() {
    load_modules
    load_optional_modules

    while true; do
        print_banner
        print_menu

        echo -ne "  ${CYAN}Enter your choice [0-9]: ${RESET}"
        read -r choice

        case "$choice" in
            1)
                print_banner
                hardware_audit
                press_enter
                ;;
            2)
                print_banner
                software_audit
                press_enter
                ;;
            3)
                print_banner
                generate_short_report
                press_enter
                ;;
            4)
                print_banner
                generate_full_report
                press_enter
                ;;
            5)
                print_banner
                send_report
                press_enter
                ;;
            6)
                print_banner
                remote_monitor
                press_enter
                ;;
            7)
                print_banner
                compare_reports
                press_enter
                ;;
            8)
                print_banner
                check_cpu_alert
                press_enter
                ;;
            9)
                print_banner
                verify_integrity
                press_enter
                ;;
            0)
                echo -e "\n  ${GREEN}Goodbye! Stay secure.${RESET}\n"
                exit 0
                ;;
            *)
                echo -e "\n  ${RED}  Invalid option. Please enter a number between 0 and 9.${RESET}"
                sleep 1
                ;;
        esac
    done
}

main