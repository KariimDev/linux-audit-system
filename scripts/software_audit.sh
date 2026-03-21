#!/bin/bash

# =============================================================
# software_audit.sh - Audits installed software and package information
#==============================================================
source "$(dirname "$0")/utils.sh"

#OS name and version
get_os_info() {
    print_section "OPERATING SYSTEM INFORMATION"
    if ! check_command lsb_release; then
        log_warn "lsb_release not found, trying /etc/os-release..."

        #[] are equal to test, and -f checks if the file exists. If /etc/os-release exists.
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

#Installed packages
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

#Logged-in users
get_logged_in_users() {
    print_section "LOGGED-IN USERS"
    if ! check_command who; then
        log_error "Cannot retrieve logged-in users information."
        return 1
    fi
    log_info "Currently logged-in users:"
    who
}

#Running services and Active processes
get_services_info() {
    print_section "SERVICES AND PROCESSES"
    if check_command systemctl; then
        log_info "Running services (systemctl):"
        systemctl list-units --type=service --state=running
    elif check_command service; then
        log_info "Running services (service):"
        service --status-all 2>/dev/null | grep '+'
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

#Open ports
get_open_ports() {
    print_section "OPEN PORTS"
    if check_command ss; then
        log_info "Open ports (ss):"
        #-tuln means: -t for TCP, -u for UDP, -l for listening, and -n for numeric output (don't resolve service names)
        ss -tuln
    elif check_command netstat; then
        log_info "Open ports (netstat):"
        netstat -tuln
    else
        log_error "No supported network tool found."
        return 1
    fi
}

#shows programs that run on boot
get_startup_programs() {
    print_section "STARTUP PROGRAMS"
    if check_command systemctl; then
        log_info "Startup services (systemctl):"
        #list-unit-files shows all services and their enabled/disabled status, and grep enabled filters only those that are set to start on boot.

        systemctl list-unit-files --type=service | grep enabled
    elif check_command chkconfig; then
        log_info "Startup services (chkconfig):"
        #chkconfig --list shows all services and their runlevel status, and grep '3:on\|4:on\|5:on' filters those that are set to start in the common multi-user runlevels (3, 4, 5).
        chkconfig --list | grep '3:on\|4:on\|5:on'
    else
        log_error "No supported service manager found."
        return 1
    fi
}