#!/bin/bash

# =============================================================
# hardware_audit.sh - Audits hardware information of the system
# =============================================================

# BASH_SOURCE[0] always points to THIS file even when sourced from main.sh
# Using $0 would point to main.sh instead, which breaks the path
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/utils.sh"


# CPU information (model, cores, architecture...)
get_cpu_info() {
    print_section "CPU INFORMATION"
    if ! check_command lscpu; then
        log_warn "lscpu not found, trying /proc/cpuinfo..."
        if [ -f /proc/cpuinfo ]; then
            grep -E 'model name|cpu cores|siblings' /proc/cpuinfo | head -6
        else
            log_error "Cannot retrieve CPU information."
            return 1
        fi
        return 0
    fi
    log_info "CPU Information:"
    # -E means extended regex — grab only the relevant lscpu lines
    lscpu | grep -E 'Model name|Socket|Core|Thread|Architecture'
}


# GPU information (if available)
get_gpu_info() {
    print_section "GPU INFORMATION"
    if ! check_command lspci; then
        # not crashing here — GPU info is optional
        log_warn "lspci not found. Cannot retrieve GPU information."
        return 0
    fi
    log_info "GPU Information:"
    # || true prevents set -e from killing the script if no GPU is found
    lspci | grep -i 'vga\|3d\|2d' || echo "  No GPU detected"
}


# RAM information (total and available memory)
get_ram_info() {
    print_section "RAM INFORMATION"
    if ! check_command free; then
        log_warn "free not found, trying /proc/meminfo..."
        if [ -f /proc/meminfo ]; then
            grep -E 'MemTotal|MemAvailable|MemFree' /proc/meminfo
        else
            log_error "Cannot retrieve RAM information."
            return 1
        fi
        return 0
    fi
    log_info "RAM Information:"
    free -h
}

# Disk information (size, partitions, usage, filesystem type)
get_disk_info() {
    print_section "DISK INFORMATION"
    if ! check_command lsblk; then
        # lsblk is preferred, fall back to fdisk if needed
        log_warn "lsblk not found, trying fdisk..."
        if check_command fdisk; then
            fdisk -l
        else
            log_error "Cannot retrieve disk information."
            return 1
        fi
        return 0
    fi
    log_info "Disk Information:"
    lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINT,TYPE

    # df shows actual usage percentages per partition
    echo ""
    if check_command df; then
        log_info "Disk Usage:"
        df -h
    fi
}

# Network interfaces (names, IP addresses, MAC addresses)
get_network_info() {
    print_section "NETWORK INFORMATION"
    if ! check_command ip; then
        log_warn "ip not found, trying ifconfig..."
        if check_command ifconfig; then
            ifconfig -a
        else
            log_error "Cannot retrieve network information."
            return 1
        fi
        return 0
    fi
    log_info "Network Information:"
    # -br = brief format, much cleaner output
    ip -br addr show

    echo ""
    log_info "MAC Addresses:"
    # || true so the script doesn't die if there are no ethernet interfaces
    ip link show | grep 'link/ether' | awk '{print $2}' || true
}

# Motherboard information (requires root / dmidecode)
get_motherboard_info() {
    print_section "MOTHERBOARD INFORMATION"
    if ! check_command dmidecode; then
        log_warn "dmidecode not found. Cannot retrieve motherboard information."
        return 0
    fi
    log_info "Motherboard Information:"
    # 2>/dev/null swallows permission errors when not root
    dmidecode -t baseboard 2>/dev/null || log_warn "Motherboard info requires root privileges."
}

# USB devices
get_usb_info() {
    print_section "USB DEVICES"
    if ! check_command lsusb; then
        log_warn "lsusb not found. Cannot retrieve USB information."
        return 0
    fi
    log_info "USB Devices:"
    lsusb
}

hardware_audit() {
    separator
    echo "        HARDWARE AUDIT — $(timestamp)"
    separator
    get_cpu_info
    get_gpu_info
    get_ram_info
    get_disk_info
    get_network_info
    get_motherboard_info
    get_usb_info
    separator
    log_info "Hardware audit complete."
}
