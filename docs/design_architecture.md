# Linux Audit System — Design Architecture

**Author:** Karim
**Date:** 2026-03-19
**Course:** Operating Systems — NSCS 2025/2026

---

## 1. Overview

The Linux Audit System is a modular shell scripting solution designed to automatically collect, report, and monitor hardware and software information on Linux systems. The system is built with cybersecurity best practices in mind, ensuring reliability, portability, and security across different Linux distributions.

---

## 2. Architecture Design

The system follows a **modular architecture** where each script is responsible for one specific task. This makes the system easy to maintain, test, and extend.

```
linux-audit-system/
├── scripts/
│   ├── utils.sh            # Shared utilities — loaded by all scripts
│   ├── hardware_audit.sh   # Hardware data collection
│   ├── software_audit.sh   # Software & OS data collection
│   ├── report_generator.sh # Report formatting & generation
│   ├── email_sender.sh     # Email transmission
│   ├── remote_monitor.sh   # Remote monitoring via SSH
│   ├── scheduler.sh        # Cron job automation
│   ├── auto_audit.sh       # Silent script called by cron
│   └── main.sh             # Entry point & interactive menu
├── config/
│   ├── audit.conf          # Main configuration
│   └── email.conf          # Email credentials (gitignored)
├── logs/                   # Runtime logs (gitignored)
├── reports/
│   └── examples/           # Example reports for submission
├── tests/                  # Test scripts
└── docs/                   # Documentation
```

---

## 3. Data Flow

### 3.1 Manual Mode (via main.sh)

The user launches `main.sh` which shows an interactive menu. Depending on the choice, it sources and calls the relevant module:

| User Choice | Module Called | What Happens |
|---|---|---|
| Hardware Audit | `hardware_audit.sh` | Collects CPU, GPU, RAM, Disk, Network, USB info |
| Software Audit | `software_audit.sh` | Collects OS, kernel, packages, services, ports |
| Short Report | `report_generator.sh` | Generates a `.txt` summary report |
| Full Report | `report_generator.sh` | Generates `.txt`, `.html`, `.json` reports |
| Send Email | `email_sender.sh` | Sends the latest report by email |
| Remote Monitor | `remote_monitor.sh` | Connects via SSH and monitors a remote machine |
| Compare Reports | `report_generator.sh` | Diffs two report files |
| CPU Alert | `report_generator.sh` | Checks if CPU exceeds the threshold |
| Log Integrity | `report_generator.sh` | Verifies log checksums with sha256sum |

### 3.2 Automated Mode (via cron)

The cron job calls `auto_audit.sh` daily at 4:00 AM with no user interaction:

```
cron (4:00 AM every day)
        |
        v
  auto_audit.sh
        |
        |---> hardware_audit.sh   (collect hardware data)
        |---> software_audit.sh   (collect software data)
        |---> report_generator.sh (generate full report)
        |---> email_sender.sh     (send report by email)
        |
        v
  logs/cron.log  (execution log)
```

---

## 4. Module Descriptions

### 4.1 `utils.sh` — Shared Utilities

The foundation of the entire system. Loaded by every other script using `source`.

| Component | Purpose |
|---|---|
| Color variables | Terminal color codes for readable output |
| `log_info()` | Logs info messages to terminal and log file |
| `log_warn()` | Logs warning messages |
| `log_error()` | Logs error messages |
| `timestamp()` | Returns current date and time |
| `check_command()` | Verifies a command exists before using it |
| `check_root()` | Warns if not running as root |
| `print_section()` | Prints formatted section headers |
| `separator()` | Prints a visual divider line |

### 4.2 `hardware_audit.sh` — Hardware Collection

Collects complete hardware information using standard Linux tools.

| Function | Command Used | Fallback |
|---|---|---|
| `get_cpu_info()` | `lscpu` | `/proc/cpuinfo` |
| `get_gpu_info()` | `lspci` | None — logs error |
| `get_ram_info()` | `free -h` | `/proc/meminfo` |
| `get_disk_info()` | `lsblk`, `df -h` | `fdisk -l` |
| `get_network_info()` | `ip addr` | `ifconfig` |
| `get_motherboard_info()` | `dmidecode` | None — requires root |
| `get_usb_info()` | `lsusb` | None — logs error |

### 4.3 `software_audit.sh` — Software Collection

Extracts comprehensive OS and software information.

| Function | Command Used | Fallback |
|---|---|---|
| `get_os_info()` | `lsb_release` | `/etc/os-release` |
| `get_kernel_info()` | `uname -r` | `/proc/version` |
| `get_arch_info()` | `uname -m` | `/proc/version` |
| `get_installed_packages()` | `dpkg -l` | `rpm -qa` |
| `get_logged_in_users()` | `who` | None — logs error |
| `get_services_info()` | `systemctl` | `service` |
| `get_open_ports()` | `ss -tuln` | `netstat -tuln` |
| `get_startup_programs()` | `systemctl` | `chkconfig` |

### 4.4 `scheduler.sh` — Automation

Manages cron job setup for automated audit execution.

| Function | Purpose |
|---|---|
| `setup_cron()` | Adds cron job — runs `auto_audit.sh` daily at 4:00 AM |
| `remove_cron()` | Removes the cron job |
| `show_cron_status()` | Shows if cron job is active |

Cron schedule used:

```
0 4 * * * bash /path/to/scripts/auto_audit.sh >> /path/to/logs/cron.log 2>&1
```

### 4.5 `auto_audit.sh` — Silent Automation Entry Point

Called exclusively by cron. Sources all modules and runs the full audit pipeline without any user interaction: collects hardware data, collects software data, generates a full report, and sends it by email.

### 4.6 `report_generator.sh` — Report Generation

Generates reports in three formats from the collected data.

| Function | Output |
|---|---|
| `generate_short_report()` | `.txt` summary |
| `generate_full_report()` | `.txt`, `.html`, `.json` |
| `compare_reports()` | Diff between two report files |
| `check_cpu_alert()` | CPU threshold alert |
| `verify_integrity()` | sha256sum log verification |

### 4.7 `email_sender.sh` — Email Delivery

| Function | Purpose |
|---|---|
| `send_report()` | Interactive — asks user which report to send |
| `send_report_auto()` | Silent — used by cron, sends latest report automatically |

Supports three email backends detected automatically: `msmtp` → `sendmail` → `mail`.

### 4.8 `remote_monitor.sh` — Remote Monitoring

| Function | Purpose |
|---|---|
| `test_ssh_connection()` | Tests SSH connectivity before proceeding |
| `monitor_remote()` | Pulls live system info from remote machine via SSH |
| `send_report_to_remote()` | Copies latest report to remote server via SCP |

---

## 5. Key Design Decisions

### 5.1 Modular Structure

Each script handles one responsibility. This makes the system easy to test each module independently, easy to maintain without breaking other parts, and easy to extend with new features.

### 5.2 Fallback Mechanisms

Every function that depends on an external command has a fallback in case that command is not installed. This ensures the system works on minimal Linux installations, different distributions (Debian, RPM-based), and systems with restricted permissions.

### 5.3 Security Considerations

- Email credentials are stored in `email.conf` which is gitignored and never pushed to GitHub
- Scripts never hardcode sensitive values — all configuration lives in `config/`
- `dmidecode` gracefully handles missing root privileges instead of crashing
- All external commands are validated with `check_command()` before use
- SSH remote monitoring uses key-based authentication — no passwords transmitted over the network

### 5.4 Error Handling Strategy

| Level | Function | Action |
|---|---|---|
| Warning | `log_warn()` | Skip and continue |
| Error | `log_error()` | Log and return 1 |
| Fatal | `exit 1` | Stop execution |

---

## 6. Commands Reference

### Hardware Commands

| Command | Purpose | Example |
|---|---|---|
| `lscpu` | CPU details | `lscpu \| grep 'Model name'` |
| `lspci` | PCI devices (GPU) | `lspci \| grep -i vga` |
| `free -h` | RAM usage | `free -h` |
| `lsblk` | Block devices | `lsblk -o NAME,SIZE,FSTYPE` |
| `df -h` | Disk usage | `df -h` |
| `ip addr` | Network interfaces | `ip -br addr show` |
| `dmidecode` | Motherboard info | `dmidecode -t baseboard` |
| `lsusb` | USB devices | `lsusb` |

### Software Commands

| Command | Purpose | Example |
|---|---|---|
| `lsb_release` | OS info | `lsb_release -a` |
| `uname` | Kernel & arch | `uname -r`, `uname -m` |
| `dpkg` | Installed packages | `dpkg -l` |
| `rpm` | Installed packages (RPM) | `rpm -qa` |
| `who` | Logged in users | `who` |
| `systemctl` | Services | `systemctl list-units --type=service` |
| `ps` | Processes | `ps aux --sort=-%cpu` |
| `ss` | Open ports | `ss -tuln` |

---

## 7. Testing Strategy

Each module has a dedicated test script in `tests/`. Tests follow this pattern: source the module, call each function and capture output, assert output is not empty or exit code is 0, and report pass/fail results.

```bash
bash tests/test_hardware.sh
bash tests/test_software.sh
```

---

## 8. Challenges Encountered

| Challenge | Solution |
|---|---|
| Different package managers across distros | Used `if/elif` to support both `dpkg` and `rpm` |
| Some commands require root | Used `2>/dev/null` and graceful warnings |
| `dmidecode` fails without root | Added `log_warn` fallback instead of crashing |
| Cron calling interactive menu | Created dedicated `auto_audit.sh` for cron |
| Cron needs absolute paths | Used `$(cd "$(dirname "$0")" && pwd)` to resolve paths |
| Email credentials security | Separated into gitignored `email.conf` |
| Line ending issues on Windows | Added `.gitattributes` to enforce Linux `LF` internally |
