#!/bin/bash

# =============================================================
# hardware_audit.sh - Audits hardware information of the system
#==============================================================

source "$(dirname "$0")/utils.sh"


#CPU information (model, cores, architecture...)
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
    #-E means extended regex, and we are looking for lines that contain "Model name", "Socket", "Core", "Thread", or "Architecture"
    lscpu | grep -E 'Model name|Socket|Core|Thread|Architecture'
}


#GPU information (if available)
get_gpu_info() {
    print_section "GPU INFORMATION"  
    if ! check_command lspci; then
        log_error "Cannot retrieve GPU information."
        return 1
    fi
    log_info "GPU Information:"
    lspci | grep -i 'vga\|3d\|2d' || echo "No GPU detected"
}


#RAM information (total and available memory)
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

#Disk information (size, partitions, usage,filesystem type)
get_disk_info() {
    print_section "DISK INFORMATION"
    if ! check_command lsblk; then
        #lsblk is the preferred way to get disk information, but if it's not available, we can try fdisk as a fallback. If neither command is available, we log an error.
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

    # df shows actual usage percentages (how full each partition is)
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
    # -br means brief format, cleaner output
    ip -br addr show

    # separately show MAC addresses
    echo ""
    log_info "MAC Addresses:"
    # grep 'link/ether' filters only MAC address lines
    # awk '{print $2}' takes the second column which is the MAC
    ip link show | grep 'link/ether' | awk '{print $2}'
}

#Motherboard information and other relevant hardware details (if available)
get_motherboard_info() {
    print_section "MOTHERBOARD INFORMATION"
    if ! check_command dmidecode; then
        log_error "Cannot retrieve motherboard information."
        return 1
    fi
    log_info "Motherboard Information:"
    # 2>/dev/null silences permission errors when not running as root
    dmidecode -t baseboard 2>/dev/null || log_warn "Motherboard info requires root privileges."
}

#USB devices
get_usb_info() {
    print_section "USB DEVICES"
    if ! check_command lsusb; then
        log_error "Cannot retrieve USB information."
        return 1
    fi
    log_info "USB Devices:"
    lsusb
}

# Make functions available when sourced by main.sh
# Do NOT call anything here, just define functions. main.sh will call them in the right order.

