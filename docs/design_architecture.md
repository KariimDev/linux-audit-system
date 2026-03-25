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
│
├── scripts/
│   ├── utils.sh            # Shared utilities — loaded by all scripts
│   ├── hardware_audit.sh   # Hardware data collection
│   ├── software_audit.sh   # Software & OS data collection
│   ├── report_generator.sh # Report formatting & generation
│   ├── email_sender.sh     # Email transmission
│   ├── remote_monitor.sh   # Remote monitoring via SSH
│   ├── scheduler.sh        # Cron job automation
│   └── main.sh             # Entry point & interactive menu
│
├── config/
│   ├── audit.conf          # Main configuration
│   └── email.conf          # Email credentials (gitignored)
│
├── logs/                   # Runtime logs (gitignored)
├── reports/                # Generated reports (gitignored)
│   └── examples/           # Example reports for submission
├── tests/                  # Test scripts
└── docs/                   # Documentation
```

---

## 3. Data Flow
```
┌─────────────────────────────────────────────────┐
│                    main.sh                       │
│              (Entry Point / Menu)                │
└──────┬──────────────────────────────────┬────────┘
       │                                  │
       ▼                                  ▼
┌─────────────┐                    ┌─────────────┐
│hardware_    │                    │software_    │
│audit.sh     │                    │audit.sh     │
│             │                    │             │
│ • CPU       │                    │ • OS Info   │
│ • GPU       │                    │ • Kernel    │
│ • RAM       │                    │ • Packages  │
│ • Disk      │                    │ • Users     │
│ • Network   │                    │ • Services  │
│ • USB       │                    │ • Ports     │
└──────┬──────┘                    └──────┬──────┘
       │                                  │
       └──────────────┬───────────────────┘
                      ▼
             ┌─────────────────┐
             │report_generator │
             │    .sh          │
             │                 │
             │ • short report  │
             │ • full report   │
             │ • txt/html/json │
             └────────┬────────┘
                      │
          ┌───────────┼───────────┐
          ▼           ▼           ▼
   ┌────────────┐ ┌────────┐ ┌──────────────┐
   │email_      │ │logs/   │ │remote_       │
   │sender.sh   │ │        │ │monitor.sh    │
   │            │ │audit   │ │              │
   │ • send     │ │.log    │ │ • SSH send   │
   │   report   │ │cron    │ │ • centralize │
   │ • attach   │ │.log    │ │   reports    │
   └────────────┘ └────────┘ └──────────────┘
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
| `setup_cron()` | Adds cron job — runs audit daily at 4:00 AM |
| `remove_cron()` | Removes the cron job |
| `show_cron_status()` | Shows if cron job is active |

Cron schedule used:
```
0 4 * * * bash /path/to/main.sh >> /path/to/logs/cron.log 2>&1
```
Meaning: at minute 0, hour 4, every day, every month, every weekday.

---

## 5. Key Design Decisions

### 5.1 Modular Structure
Each script handles one responsibility. This follows the **Single Responsibility Principle** — the same principle used in good software engineering. It makes the system:
- Easy to test each module independently
- Easy to maintain without breaking other parts
- Easy to extend with new features

### 5.2 Fallback Mechanisms
Every function that depends on an external command has a fallback in case that command is not installed. This ensures the system works on:
- Minimal Linux installations
- Different Linux distributions (Debian, RPM-based, Arch)
- Systems with restricted permissions

### 5.3 Security Considerations
- Email credentials are stored in `email.conf` which is **gitignored** — never pushed to GitHub
- Scripts never hardcode sensitive values — all configuration is in `config/`
- `dmidecode` gracefully handles missing root privileges instead of crashing
- All external commands are validated with `check_command()` before use
- SSH remote monitoring uses key-based authentication — no passwords transmitted

### 5.4 Error Handling Strategy
Three levels of error handling are used throughout:

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

Each module has a dedicated test script in `tests/`. Tests follow this pattern:

1. Source the module being tested
2. Call each function and capture output
3. Assert output is not empty or exit code is 0
4. Report pass/fail results

Run tests:
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
| Cron needs absolute paths | Used `$(cd "$(dirname "$0")" && pwd)` to get absolute path |
| Email credentials security | Separated into gitignored `email.conf` |
| Line ending issues on Windows | Used Git Bash which handles LF/CRLF automatically |