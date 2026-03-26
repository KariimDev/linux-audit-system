#!/bin/bash
# software_audit.sh - Audits installed software and package information
# Author: Karim

# BASH_SOURCE[0] always refers to this file, not the caller
# Needed so the path is correct when sourced from main.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"

# OS name and version
get_os_info() {
    print_section "OPERATING SYSTEM INFORMATION"
    if ! check_command lsb_release; then
        log_warn "lsb_release not found, trying /etc/os-release..."
        if [ -f /etc/os-release ]; then
            grep -E 'PRETTY_NAME|VERSION' /etc/os-release
        else
            log_error "Cannot retrieve OS information."
            return 1
        fi
        return 0
    fi
    log_info "Operating System Information:"
    lsb_release -a
}

# Kernel version
get_kernel_info() {
    print_section "KERNEL INFORMATION"
    if ! check_command uname; then
        log_error "Cannot retrieve kernel information."
        return 1
    fi
    log_info "Kernel Information:"
    uname -r
}

# System architecture
get_arch_info() {
    print_section "ARCHITECTURE INFORMATION"
    if ! check_command uname; then
        log_error "Cannot retrieve architecture information."
        return 1
    fi
    log_info "System Architecture:"
    uname -m
}

# Installed packages
get_installed_packages() {
    print_section "INSTALLED PACKAGES"
    if check_command dpkg; then
        log_info "Installed packages (dpkg):"
        dpkg -l
    elif check_command rpm; then
        log_info "Installed packages (rpm):"
        rpm -qa
    else
        log_error "No supported package manager found."
        return 1
    fi
}

# Logged-in users
get_logged_in_users() {
    print_section "LOGGED-IN USERS"
    if ! check_command who; then
        log_error "Cannot retrieve logged-in users information."
        return 1
    fi
    log_info "Currently logged-in users:"
    who
}

# Running services and active processes
get_services_info() {
    print_section "SERVICES AND PROCESSES"
    if check_command systemctl; then
        log_info "Running services (systemctl):"
        systemctl list-units --type=service --state=running
    elif check_command service; then
        log_info "Running services (service):"
        # || true because grep exits 1 when nothing matches — don't let set -e kill us
        service --status-all 2>/dev/null | grep '+' || true
    else
        log_error "No supported service manager found."
        return 1
    fi

    if check_command ps; then
        log_info "Active processes (top 20 by CPU usage):"
        ps aux --sort=-%cpu | head -20
    else
        log_error "Cannot retrieve active processes information."
        return 1
    fi
}

# Open ports
get_open_ports() {
    print_section "OPEN PORTS"
    if check_command ss; then
        log_info "Open ports (ss):"
        # -t TCP  -u UDP  -l listening only  -n numeric (no service name resolving)
        ss -tuln
    elif check_command netstat; then
        log_info "Open ports (netstat):"
        netstat -tuln
    else
        log_error "No supported network tool found."
        return 1
    fi
}

# Programs that start on boot
get_startup_programs() {
    print_section "STARTUP PROGRAMS"
    if check_command systemctl; then
        log_info "Startup services (systemctl):"
        # || true because grep returns 1 when nothing matches — safe to ignore here
        systemctl list-unit-files --type=service | grep enabled || true
    elif check_command chkconfig; then
        log_info "Startup services (chkconfig):"
        chkconfig --list | grep '3:on\|4:on\|5:on' || true
    else
        log_error "No supported service manager found."
        return 1
    fi
}

software_audit() {
    separator
    echo "        SOFTWARE AUDIT — $(timestamp)"
    separator
    get_os_info
    get_kernel_info
    get_arch_info
    get_installed_packages
    get_logged_in_users
    get_services_info
    get_open_ports
    get_startup_programs
    separator
    log_info "Software audit complete."
}