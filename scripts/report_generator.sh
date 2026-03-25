#!/usr/bin/env bash
 
# -e Stop the script if any command fails
# -u Stop if you use a variable you forgot to define
# -o pipefail Stop if a command inside a pipe | fails
set -euo pipefail
 
# Find where THIS script is, works on all machines
#dirname: This command takes a full path and removes the filename, leaving only the directory part.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
 
# Go one folder up = the project root
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
 
# If utils.sh exists load it, if not define colors manually
if [[ -f "$SCRIPT_DIR/utils.sh" ]]; then

#When a script runs this line, it doesn't just "run" utils.sh as a separate program. Instead, 
#it pulls everything inside utils.sh—such as variables, aliases, and functions—directly into the main script.
    source "$SCRIPT_DIR/utils.sh"
else
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    CYAN='\033[0;36m'
    BOLD='\033[1m'
    RESET='\033[0m'
fi
 
# Load the config file if it exists
if [[ -f "$PROJECT_ROOT/config/audit.conf" ]]; then
    source "$PROJECT_ROOT/config/audit.conf"
else
    # If config is missing, use default values
    REPORT_DIR="/var/log/sys_audit"
    CPU_THRESHOLD=80
fi
 
# Create the report directory if it does not exist yet
# -p mean dont show error if it already exists
mkdir -p "$REPORT_DIR"
 
# FUNCTION: Generate a short summary report
# Saves as .txt file
generate_short_report() {
 
    # Build the filename with current date and time
    # ex short_report_2026-03-23_14-35-02.txt
    local filename="short_report_$(date '+%Y-%m-%d_%H-%M-%S').txt"
 
    # Full path where the file will be saved
    local filepath="$REPORT_DIR/$filename"
    #The echo -e command is a specific flag used in Bash and other shells that tells the system to enable the interpretation of backslash escapes.
    echo -e "${CYAN}${BOLD}  [ Generating Short Report... ]${RESET}"
    echo ""
 
    # Everything inside { } will be written into the file
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
        #Searches the system info file for the line containing the OS name 
        # Splits the line at the = sign and keeps the second part (the name).
        # Deletes the quotation marks for a cleaner look.
        echo "  OS       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
        echo "  Kernel   : $(uname -r)"
        echo "  Arch     : $(uname -m)"
        echo ""
 
        echo "--- CPU ---"
        # grep finds the model name line, head takes first one, cut removes the labeland xargs remove spaces and something to be more orgenized
        echo "  Model    : $(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)"
        # Count how many CPU cores the machine has
        echo "  Cores    : $(nproc)"
        echo ""
 
        echo "--- MEMORY ---"
        # free -h shows memory in human readable format (GB/MB)
        # awk picks the second line (Mem:) and prints used/total
        # The $2, $3, $4 refer to the columns in the output of free -h (total, used, free)
        free -h | awk '/^Mem:/ {print "  Total: " $2 "  |  Used: " $3 "  |  Free: " $4}'
        echo ""
 
        echo "--- DISK ---"
        # df -h shows disk space in human readable format
        # awk skips the header line and prints each partition
        df -h | awk 'NR>1 {print "  " $1 " → Size: " $2 " | Used: " $3 " | Free: " $4}'
        echo ""
 
        echo "--- NETWORK ---"
        # ip a shows all network interfaces
        # grep finds lines with IP addresses (inet)
        # awk prints just the IP address
        ip a | grep "inet " | awk '{print "  " $2}'
        echo ""
 
        echo "======================================"
        echo "  END OF SHORT REPORT"
        echo "======================================"
 
    # The > saves everything above into the file
    } > "$filepath"
 
    # Tell the user where the file was saved
    echo -e "  ${GREEN}Short report saved to:${RESET} $filepath"
    echo ""
}
 
 
# FUNCTION: Generate a full detailed report
# Saves as .txt AND .html AND .json
generate_full_report() {
 
    local base="full_report_$(date '+%Y-%m-%d_%H-%M-%S')"
     local txt_file="$REPORT_DIR/$base.txt"
    local html_file="$REPORT_DIR/$base.html"
    local json_file="$REPORT_DIR/$base.json"
 
    echo -e "${CYAN}${BOLD}  [ Generating Full Report... ]${RESET}"
    echo ""
 
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
        # Print all CPU info lines from /proc/cpuinfo
        grep 'model name\|cpu MHz\|cache size' /proc/cpuinfo | sort -u | \
            awk -F: '{print "  " $1 ": " $2}'
        echo ""
 
        echo "[ GPU ]"
        # lspci lists hardware devices, grep finds the VGA/display card
        # 2>/dev/null hides errors if lspci is not installed
        lspci 2>/dev/null | grep -i "vga\|3d\|display" | \
            awk '{print "  " $0}' || echo "  GPU info not available"
        echo ""
 
        echo "[ RAM ]"
        # free -h shows full memory table
        free -h | awk '{print "  " $0}'
        echo ""
 
        echo "[ DISK ]"
        # lsblk shows disk partitions in a tree view
        lsblk | awk '{print "  " $0}'
        echo ""
 
        echo "[ USB DEVICES ]"
        # lsusb lists all connected USB devices
        lsusb 2>/dev/null | awk '{print "  " $0}' || echo "  lsusb not available"
        echo ""
 
        echo "[ MOTHERBOARD ]"
        # dmidecode reads hardware info from the BIOS
        # -t baseboard means we want info about the motherboard only
        sudo dmidecode -t baseboard 2>/dev/null | grep -i "manufacturer\|product\|version" | \
            awk '{print "  " $0}' || echo "  dmidecode not available"
        echo ""
 
        echo "━━━ NETWORK ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
 
        echo "[ IP ADDRESSES ]"
        ip a | grep "inet " | awk '{print "  " $2}'
        echo ""
 
        echo "[ MAC ADDRESSES ]"
        # ip link shows network interfaces with MAC addresses
        ip link | grep "link/ether" | awk '{print "  " $2}'
        echo ""
 
        echo "[ DEFAULT GATEWAY ]"
        # ip route shows routing table, grep finds the default gateway line
        ip route | grep default | awk '{print "  " $3}'
        echo ""
 
        echo "[ DNS SERVERS ]"
        grep "nameserver" /etc/resolv.conf | awk '{print "  " $2}'
        echo ""
 
        echo "━━━ SOFTWARE & OS ━━━━━━━━━━━━━━━━━━━━━━━━━━"
        echo ""
 
        echo "[ OS INFO ]"
        # about cut Splits the line at the equals sign (=) and keeps the second part (the name). 
        # tr -d '"' removes the quotation marks for a cleaner look.
        echo "  OS       : $(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')"
        echo "  Kernel   : $(uname -r)"
        echo "  Arch     : $(uname -m)"
        echo "  Uptime   : $(uptime -p)"
        echo ""
 
        echo "[ LOGGED IN USERS ]"
        who | awk '{print "  " $0}'
        echo ""
 
        echo "[ RUNNING SERVICES ]"
        # systemctl lists all active services
        #systemctl list-units → lists all system services
        #--type=service → only show services
        #--state=running → only show ones that are currently running
        # head -20 shows only the first 20 to keep it clean
        systemctl list-units --type=service --state=running 2>/dev/null | \
            head -20 | awk '{print "  " $0}'
        echo ""
 
        echo "[ ACTIVE PROCESSES (Top 10 by CPU) ]"
        # ps aux lists all processes
        # sort by CPU column (3rd), show top 10
        ps aux --sort=-%cpu | head -11 | awk '{print "  " $0}'
        echo ""
 
        echo "[ OPEN PORTS ]"
        # ss -tuln shows all open TCP/UDP ports
        # if ss is not available, fallback to netstat
        ss -tuln 2>/dev/null | awk '{print "  " $0}' || \
            netstat -tuln 2>/dev/null | awk '{print "  " $0}'
        echo ""
 
        echo "[ INSTALLED PACKAGES COUNT ]"
        
        #commrnd -v dpkg checks if dpkg is available Debian Ubuntu
        # Count how many packages are installed
        #elif checks if rpm is available RedHat
        # works on Debian/Ubuntu (dpkg) or RedHat (rpm)
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
 
    # ── HTML VERSION ─────────────────────────────────────────
    {
        # Write a basic HTML page structure
        echo "<!DOCTYPE html>"
        echo "<html lang='en'>"
        echo "<head>"
        echo "  <meta charset='UTF-8'>"
        echo "  <title>Linux Audit Report</title>"
        # Inline CSS to make the page look professional
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
        echo "  <h1>🛡 Linux System Audit — Full Report</h1>"
        echo "  <p class='info'>Date: $(date '+%A, %d %B %Y — %H:%M:%S')</p>"
        echo "  <p class='info'>Hostname: $(hostname) | User: $(whoami)</p>"
 
        echo "  <h2>CPU</h2><pre>"
        grep 'model name\|cpu MHz' /proc/cpuinfo | sort -u
        echo "  </pre>"
 
        echo "  <h2>Memory</h2><pre>"
        free -h
        echo "  </pre>"
 
        echo "  <h2>Disk</h2><pre>"
        df -h
        echo "  </pre>"
 
        echo "  <h2>Network</h2><pre>"
        ip a | grep "inet "
        echo "  </pre>"
 
        echo "  <h2>Open Ports</h2><pre>"
        ss -tuln 2>/dev/null || netstat -tuln 2>/dev/null
        echo "  </pre>"
 
        echo "  <h2>Running Services</h2><pre>"
        systemctl list-units --type=service --state=running 2>/dev/null | head -20
        echo "  </pre>"
 
        echo "  <p class='footer'>Generated by Linux Audit Tool — NSCS 2025/2026</p>"
        echo "</body>"
        echo "</html>"
 
    } > "$html_file"
 
    # ── JSON VERSION ─────────────────────────────────────────
    {
        # Write a JSON object with key system information
        echo "{"
        # jq-style manual JSON — we build it with echo
        echo "  \"report_type\": \"full\","
        echo "  \"generated_at\": \"$(date '+%Y-%m-%dT%H:%M:%S')\","
        echo "  \"hostname\": \"$(hostname)\","
        echo "  \"user\": \"$(whoami)\","
        echo "  \"os\": \"$(grep PRETTY_NAME /etc/os-release | cut -d= -f2 | tr -d '"')\","
        echo "  \"kernel\": \"$(uname -r)\","
        echo "  \"architecture\": \"$(uname -m)\","
        echo "  \"cpu_model\": \"$(grep 'model name' /proc/cpuinfo | head -1 | cut -d: -f2 | xargs)\","
        echo "  \"cpu_cores\": $(nproc),"
        # RAM total — get numbers only (remove unit)
        echo "  \"ram_total\": \"$(free -h | awk '/^Mem:/ {print $2}')\","
        echo "  \"ram_used\": \"$(free -h | awk '/^Mem:/ {print $3}')\","
        echo "  \"uptime\": \"$(uptime -p)\""
        echo "}"
 
    } > "$json_file"
 
    # Tell the user all 3 files were saved
    echo -e "  ${GREEN}Full report saved:${RESET}"
    echo -e "  TXT  → $txt_file"
    echo -e "  HTML → $html_file"
    echo -e "  JSON → $json_file"
    echo ""
}
 
check_cpu_alert() {
 
    echo -e "${CYAN}${BOLD}  [ CPU Alert Check ]${RESET}"
    echo ""
 
    # top -bn1 runs top once (not interactive)
    # grep finds the CPU line
    # awk extracts the idle percentage (how much CPU is FREE)
    #tr -d '%,' → remove the % and , characters to get a clean number
    local cpu_idle
    cpu_idle=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}' | tr -d '%,')
 
    # Calculate how much CPU is USED = 100 - idle
    # bc is a calculator tool in bash
    local cpu_used
    cpu_used=$(echo "100 - $cpu_idle" | bc)
 
    echo -e "  ${YELLOW}Current CPU Usage: ${cpu_used}%${RESET}"
    echo -e "  ${YELLOW}Alert Threshold  : ${CPU_THRESHOLD}%${RESET}"
    echo ""
}
 check_cpu_alert() {

    # Compare cpu_used with the threshold
    # -gt means greater than
    if (( $(echo "$cpu_used > $CPU_THRESHOLD" | bc -l) )); then
        # CPU is too high — show a red warning
        echo -e "  ${RED}⚠  WARNING: CPU usage is above ${CPU_THRESHOLD}%!${RESET}"
        echo -e "  ${RED}   Consider checking running processes.${RESET}"
        echo ""
 
        # Log the alert into a file for records
        local log_file="$REPORT_DIR/cpu_alerts.log"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] CPU ALERT — Usage: ${cpu_used}% (Threshold: ${CPU_THRESHOLD}%)" >> "$log_file"
        echo -e "  ${YELLOW}Alert logged to: $log_file${RESET}"
    else
        # CPU is fine — show a green ok message
        echo -e "  ${GREEN}✔  CPU usage is normal (${cpu_used}% < ${CPU_THRESHOLD}%)${RESET}"
    fi
    echo ""
}
 