#!/usr/bin/env bash

# -e  stop if a command fails
# -u  stop if you reference an undefined variable
# -o pipefail  stop if any command inside a pipe fails
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

# Pull in the config — use defaults if the file is missing
if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    REPORT_DIR="$PROJECT_ROOT/reports"
    CPU_THRESHOLD=80
fi

# Create the report directory — uses project-local path to avoid needing sudo
mkdir -p "$REPORT_DIR"


# ── SHORT REPORT ──────────────────────────────────────────────
generate_short_report() {
    local filename="short_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
    local filepath="$REPORT_DIR/$filename"

    echo -e "${CYAN}${BOLD}  [ Generating Short Report... ]${RESET}"
    echo ""

    {
        echo "======================================"
        echo "   LINUX SYSTEM AUDIT — SHORT REPORT"
        echo "======================================"
        echo "  Date     : $(date '+%A, %d %B %Y — %H:%M:%S')"
        echo "  Hostname : $(hostname)"
        echo "  User     : $(whoami)"
        echo "======================================"
        echo ""

        echo "--- OS INFO ---"
        echo "  OS       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
        echo "  Kernel   : $(uname -r)"
        echo "  Arch     : $(uname -m)"
        echo ""

        echo "--- CPU ---"
        echo "  Model    : $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
        echo "  Cores    : $(nproc)"
        echo ""

        echo "--- MEMORY ---"
        # awk prints total, used, free from the Mem: line
        free -h | awk '/^Mem:/ {print "  Total: " $2 "  |  Used: " $3 "  |  Free: " $4}'
        echo ""

        echo "--- DISK ---"
        df -h | awk 'NR>1 {print "  " $1 " → Size: " $2 " | Used: " $3 " | Free: " $4}'
        echo ""

        echo "--- NETWORK ---"
        # || true so the script doesn't die if there are no inet addresses
        ip a | grep "inet " | awk '{print "  " $2}' || true
        echo ""

        echo "======================================"
        echo "  END OF SHORT REPORT"
        echo "======================================"

    } > "$filepath"

    echo -e "  ${GREEN}Short report saved to:${RESET} $filepath"
    echo ""
}


# ── FULL REPORT ───────────────────────────────────────────────
generate_full_report() {
    local base="full_report_$(date '+%Y-%m-%d_%H-%M-%S')"
    local txt_file="$REPORT_DIR/$base.txt"
    local html_file="$REPORT_DIR/$base.html"
    local json_file="$REPORT_DIR/$base.json"

    echo -e "${CYAN}${BOLD}  [ Generating Full Report... ]${RESET}"
    echo ""

    # ── TXT ──────────────────────────────────────────────
    {
        echo "=============================================="
        echo "   LINUX SYSTEM AUDIT — FULL REPORT"
        echo "=============================================="
        echo "  Date     : $(date '+%A, %d %B %Y — %H:%M:%S')"
        echo "  Hostname : $(hostname)"
        echo "  User     : $(whoami)"
        echo "=============================================="
        echo ""

        echo "━━━ HARDWARE ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        echo "[ CPU ]"
        grep 'model name\|cpu MHz\|cache size' /proc/cpuinfo | sort -u | \
            awk -F: '{print "  " $1 ": " $2}'
        echo ""

        echo "[ GPU ]"
        # lspci might not be installed — silently skip if missing
        lspci 2>/dev/null | grep -i "vga\|3d\|display" | \
            awk '{print "  " $0}' || echo "  GPU info not available"
        echo ""

        echo "[ RAM ]"
        free -h | awk '{print "  " $0}'
        echo ""

        echo "[ DISK ]"
        lsblk | awk '{print "  " $0}'
        echo ""

        echo "[ USB DEVICES ]"
        lsusb 2>/dev/null | awk '{print "  " $0}' || echo "  lsusb not available"
        echo ""

        echo "[ MOTHERBOARD ]"
        # dmidecode needs root — || true so we don't crash without it
        dmidecode -t baseboard 2>/dev/null | grep -i "manufacturer\|product\|version" | \
            awk '{print "  " $0}' || echo "  dmidecode not available or requires root"
        echo ""

        echo "━━━ NETWORK ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        echo "[ IP ADDRESSES ]"
        ip a | grep "inet " | awk '{print "  " $2}' || true
        echo ""

        echo "[ MAC ADDRESSES ]"
        ip link | grep "link/ether" | awk '{print "  " $2}' || true
        echo ""

        echo "[ DEFAULT GATEWAY ]"
        ip route | grep default | awk '{print "  " $3}' || true
        echo ""

        echo "[ DNS SERVERS ]"
        grep "nameserver" /etc/resolv.conf | awk '{print "  " $2}' || true
        echo ""

        echo "━━━ SOFTWARE & OS ━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""

        echo "[ OS INFO ]"
        echo "  OS       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
        echo "  Kernel   : $(uname -r)"
        echo "  Arch     : $(uname -m)"
        echo "  Uptime   : $(uptime -p)"
        echo ""

        echo "[ LOGGED IN USERS ]"
        who | awk '{print "  " $0}'
        echo ""

        echo "[ RUNNING SERVICES ]"
        systemctl list-units --type=service --state=running 2>/dev/null | \
            head -20 | awk '{print "  " $0}' || true
        echo ""

        echo "[ ACTIVE PROCESSES (Top 10 by CPU) ]"
        ps aux --sort=-%cpu | head -11 | awk '{print "  " $0}' || true
        echo ""

        echo "[ OPEN PORTS ]"
        ss -tuln 2>/dev/null | awk '{print "  " $0}' || \
            netstat -tuln 2>/dev/null | awk '{print "  " $0}' || true
        echo ""

        echo "[ INSTALLED PACKAGES COUNT ]"
        if command -v dpkg &>/dev/null; then
            echo "  Total packages (dpkg): $(dpkg -l | grep -c '^ii')"
        elif command -v rpm &>/dev/null; then
            echo "  Total packages (rpm): $(rpm -qa | wc -l)"
        else
            echo "  Package manager not detected"
        fi
        echo ""

        echo "=============================================="
        echo "  END OF FULL REPORT"
        echo "=============================================="

    } > "$txt_file"

    # ── HTML ──────────────────────────────────────────────
    {
        echo "<!DOCTYPE html>"
        echo "<html lang='en'>"
        echo "<head>"
        echo "  <meta charset='UTF-8'>"
        echo "  <title>Linux Audit Report</title>"
        echo "  <style>"
        echo "    body { font-family: monospace; background: #0d1117; color: #c9d1d9; padding: 20px; }"
        echo "    h1 { color: #58a6ff; border-bottom: 1px solid #30363d; padding-bottom: 10px; }"
        echo "    h2 { color: #3fb950; margin-top: 30px; }"
        echo "    pre { background: #161b22; padding: 15px; border-radius: 6px; overflow-x: auto; }"
        echo "    .info { color: #e3b341; }"
        echo "    .footer { color: #8b949e; font-size: 12px; margin-top: 40px; }"
        echo "  </style>"
        echo "</head>"
        echo "<body>"
        echo "  <h1>&#127697; Linux System Audit — Full Report</h1>"
        echo "  <p class='info'>Date: $(date '+%A, %d %B %Y — %H:%M:%S')</p>"
        echo "  <p class='info'>Hostname: $(hostname) | User: $(whoami)</p>"

        echo "  <h2>CPU</h2><pre>"
        grep 'model name\|cpu MHz' /proc/cpuinfo | sort -u || true
        echo "  </pre>"

        echo "  <h2>Memory</h2><pre>"
        free -h || true
        echo "  </pre>"

        echo "  <h2>Disk</h2><pre>"
        df -h || true
        echo "  </pre>"

        echo "  <h2>Network</h2><pre>"
        ip a | grep "inet " || true
        echo "  </pre>"

        echo "  <h2>Open Ports</h2><pre>"
        ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null || true
        echo "  </pre>"

        echo "  <h2>Running Services</h2><pre>"
        systemctl list-units --type=service --state=running 2>/dev/null | head -20 || true
        echo "  </pre>"

        echo "  <p class='footer'>Generated by Linux Audit Tool — NSCS 2025/2026</p>"
        echo "</body>"
        echo "</html>"

    } > "$html_file"

    # ── JSON ──────────────────────────────────────────────
    {
        echo "{"
        echo "  \"report_type\": \"full\","
        echo "  \"generated_at\": \"$(date '+%Y-%m-%dT%H:%M:%S')\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"user\": \"$(whoami)\","
        echo "  \"os\": \"$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')\","
        echo "  \"kernel\": \"$(uname -r)\","
        echo "  \"architecture\": \"$(uname -m)\","
        echo "  \"cpu_model\": \"$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)\","
        echo "  \"cpu_cores\": $(nproc),"
        # free -h gives human-readable values like "15G" — that is the intended format here
        echo "  \"ram_total\": \"$(free -h | awk '/^Mem:/ {print $2}')\","
        echo "  \"ram_used\": \"$(free -h | awk '/^Mem:/ {print $3}')\","
        echo "  \"uptime\": \"$(uptime -p)\""
        echo "}"

    } > "$json_file"

    echo -e "  ${GREEN}Full report saved:${RESET}"
    echo -e "  TXT  → $txt_file"
    echo -e "  HTML → $html_file"
    echo -e "  JSON → $json_file"
    echo ""
}


# ── CPU ALERT CHECK ───────────────────────────────────────────
check_cpu_alert() {
    echo -e "${CYAN}${BOLD}  [ CPU Alert Check ]${RESET}"
    echo ""

    # top -bn1 runs one iteration then exits
    # The idle % column label differs by distro — we grab the number after "id,"
    # which is the standard format in most top versions
    local cpu_idle
    cpu_idle=$(top -bn1 | grep -i "cpu" | grep -oP '\d+\.\d+(?=\s*id)' | head -1)

    # Fallback: if top didn't give us what we need, use /proc/stat instead
    if [[ -z "$cpu_idle" ]]; then
        log_warn "Could not parse CPU idle from top — reading /proc/stat instead"
        local idle total
        read -r _ user nice system idle iowait irq softirq < /proc/stat
        total=$(( user + nice + system + idle + iowait + irq + softirq ))
        # scale=2 gives two decimal places
        cpu_idle=$(awk "BEGIN {printf \"%.2f\", ($idle / $total) * 100}")
    fi

    local cpu_used
    cpu_used=$(awk "BEGIN {printf \"%.0f\", 100 - $cpu_idle}")

    echo -e "  ${YELLOW}Current CPU Usage: ${cpu_used}%${RESET}"
    echo -e "  ${YELLOW}Alert Threshold  : ${CPU_THRESHOLD}%${RESET}"
    echo ""

    # awk handles the float comparison — no dependency on bc
    if awk "BEGIN {exit !($cpu_used > $CPU_THRESHOLD)}"; then
        echo -e "  ${RED}WARNING: CPU usage is above ${CPU_THRESHOLD}%!${RESET}"
        echo -e "  ${RED}Consider checking running processes.${RESET}"
        echo ""
        local log_file="$REPORT_DIR/cpu_alerts.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CPU ALERT — Usage: ${cpu_used}% (Threshold: ${CPU_THRESHOLD}%)" >> "$log_file"
        echo -e "  ${YELLOW}Alert logged to: $log_file${RESET}"
    else
        echo -e "  ${GREEN}CPU usage is normal (${cpu_used}% < ${CPU_THRESHOLD}%)${RESET}"
    fi
    echo ""
}


# ── COMPARE REPORTS ───────────────────────────────────────────
compare_reports() {
    echo -e "${CYAN}${BOLD}  [ Compare Two Reports ]${RESET}"
    echo ""

    if ! check_command diff; then
        log_error "diff not found — cannot compare reports."
        return 1
    fi

    # List available txt reports so the user can pick from them
    echo -e "  ${YELLOW}Available reports in $REPORT_DIR:${RESET}"
    # || true in case the directory is empty
    ls "$REPORT_DIR"/*.txt 2>/dev/null | awk '{print "  " NR ") " $0}' || true
    echo ""

    echo -ne "  ${CYAN}Enter path to FIRST report : ${RESET}"
    read -r report1

    echo -ne "  ${CYAN}Enter path to SECOND report: ${RESET}"
    read -r report2

    if [[ ! -f "$report1" ]]; then
        echo -e "  ${RED}[ERROR] File not found: $report1${RESET}"
        return 1
    fi

    if [[ ! -f "$report2" ]]; then
        echo -e "  ${RED}[ERROR] File not found: $report2${RESET}"
        return 1
    fi

    echo ""
    echo -e "  ${YELLOW}Differences between reports:${RESET}"
    echo ""

    # diff returns 1 when files differ — that's expected, not an error
    diff --color=always "$report1" "$report2" || true
    echo ""
}


# ── VERIFY LOG INTEGRITY ──────────────────────────────────────
verify_integrity() {
    echo -e "${CYAN}${BOLD}  [ Log Integrity Verification ]${RESET}"
    echo ""

    if ! check_command sha256sum; then
        log_error "sha256sum not found — cannot verify integrity."
        return 1
    fi

    local checksum_file="$REPORT_DIR/checksums.sha256"

    echo -e "  ${YELLOW}[1]${RESET} Generate checksums for all current reports"
    echo -e "  ${YELLOW}[2]${RESET} Verify reports against saved checksums"
    echo ""
    echo -ne "  ${CYAN}Enter your choice [1-2]: ${RESET}"
    read -r integrity_choice

    case "$integrity_choice" in
        1)
            # Generate a fresh checksum file from all txt/html/json reports
            sha256sum "$REPORT_DIR"/*.txt "$REPORT_DIR"/*.html "$REPORT_DIR"/*.json \
                2>/dev/null > "$checksum_file" || true
            echo -e "  ${GREEN}Checksums saved to: $checksum_file${RESET}"
            ;;
        2)
            if [[ ! -f "$checksum_file" ]]; then
                echo -e "  ${RED}[ERROR] No checksum file found. Generate checksums first.${RESET}"
                return 1
            fi
            echo ""
            # sha256sum -c exits 1 if anything has changed — that's the point
            if sha256sum -c "$checksum_file" 2>/dev/null; then
                echo -e "\n  ${GREEN}All files verified — no tampering detected.${RESET}"
            else
                echo -e "\n  ${RED}WARNING: One or more files have been modified!${RESET}"
            fi
            ;;
        *)
            echo -e "  ${RED}Invalid choice.${RESET}"
            return 1
            ;;
    esac
    echo ""
}