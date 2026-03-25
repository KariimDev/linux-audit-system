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

# this is a function like mini script in the script
print_banner() {
    clear
    # switch ON cyan + bold color this is like a switsh on off for colors
    echo -e "${CYAN}${BOLD}"
    echo "  ================================================"
    echo "       Linux System Audit & Monitoring Tool"
    echo "       NSCS — Academic Year 2025/2026"
    echo "  ================================================"
    # switch OFF all colors
    echo -e "${RESET}"
    # Print current date and time in yellow → Saturday, 21 March 2026 — 14:35:02
    echo -e "${YELLOW}   $(date '+%A, %d %B %Y — %H:%M:%S')${RESET}"
    echo ""
}

# print the main menu options
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

# a function to pause and wait for user to press Enter
press_enter() {
    echo ""
    echo -e "  ${YELLOW}Press Enter to return to the menu...${RESET}"
    read -r
}

# a function to source Person A scripts safely
load_modules() {
    local modules=("hardware_audit.sh" "software_audit.sh")
    #[@] means all elements
    for module in "${modules[@]}"; do
        if [[ -f "$SCRIPT_DIR/$module" ]]; then
        #Checks if the file exists at the path $SCRIPT_DIR/$module
        #-f is this a regular file not a directory, symlink, etc
        #Loads and executes the module file in the current shell context.
        #source (same as .) means the module's variables and functions become available to the current script — unlike running it as a subprocess.
            source "$SCRIPT_DIR/$module"
        else
            echo -e "${RED}  error missing module: $module${RESET}"
        fi
    done
}

# keeps the menu alive until user exits
main() {
    load_modules

    while true; do
        print_banner
        print_menu

        # Ask user to pick an option
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
                source "$SCRIPT_DIR/report_generator.sh"
                generate_short_report
                press_enter
                ;;
            4)
                print_banner
                source "$SCRIPT_DIR/report_generator.sh"
                generate_full_report
                press_enter
                ;;
            5)
                print_banner
                source "$SCRIPT_DIR/email_sender.sh"
                send_report
                press_enter
                ;;
            6)
                print_banner
                source "$SCRIPT_DIR/remote_monitor.sh"
                remote_monitor
                press_enter
                ;;
            7)
                print_banner
                source "$SCRIPT_DIR/report_generator.sh"
                compare_reports
                press_enter
                ;;
            8)
                print_banner
                source "$SCRIPT_DIR/report_generator.sh"
                check_cpu_alert
                press_enter
                ;;
            9)
                print_banner
                source "$SCRIPT_DIR/report_generator.sh"
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