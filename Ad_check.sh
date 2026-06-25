#!/bin/bash

# ==============================================================================
# Script Name    : RHEL_Precheck.sh
# Description    : Performs an advanced system pre-check for RHEL 9 environments.
# Author         : Sujit Sarkar
# Version        : 2.1.0
# Date Modified  : $(date +%F)
# ==============================================================================
# Directory/File : /scripts/log/Precheck_$(hostname)_$(date +%F_%H-%M-%S).log 
# Notes          : Requires root privileges.
# ==============================================================================

# --- COLOR & FORMATTING DEFINITIONS ---
CYAN='\033[1;36m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
RED='\033[1;31m'
NC='\033[0m'
BOLD='\033[1m'

# Check if run as root
if [[ "$EUID" -ne 0 ]]; then
  echo -e "${RED}[-] ERROR: This script must be run as root (sudo).${NC}" >&2
  exit 1
fi

# Ensure the log directory exists
LOG_DIR="/scripts/log"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/Precheck_$(hostname)_$(date +%F_%H-%M-%S).log"

# --- HELPER FUNCTIONS ---
print_header() {
  echo -e "\n${CYAN}======================================================================${NC}"
  echo -e "${CYAN}${BOLD} $1${NC}"
  echo -e "${CYAN}======================================================================${NC}"
}

check_cmd() {
  command -v "$1" >/dev/null 2>&1
}

# --- MAIN LOGIC WRAPPER ---
# Wrapping the logic allows us to pipe everything to tee safely
main() {
    echo -e "${GREEN}${BOLD}"
    echo "======================================================================"
    echo "                   RHEL 9 ADVANCED SYSTEM PRE-CHECK                   "
    echo "======================================================================"
    echo -e "${NC}"
    echo -e "Target Host : ${BOLD}$(hostname)${NC}"
    echo -e "IP Address  : ${BOLD}$(hostname -I | awk '{print $1}')${NC}"
    echo -e "Log File    : ${BOLD}$LOG_FILE${NC}"

    # 1. View RHEL Version
    print_header "1. OS Version & Security Posture"
    echo -e "\n[+] RHEL Release:"
    cat /etc/redhat-release
    
    echo -e "\n[+] SELinux Status:"
    if check_cmd getenforce; then
        getenforce
    else
        echo "SELinux utilities not found."
    fi

    # 2. Kernel Release Version
    print_header "2. Kernel Release Version"
    uname -r

    # 3. Server Hostname Details
    print_header "3. Server Hostname Details"
    hostnamectl | grep -E "Static hostname|Icon name|Chassis|Machine ID|Boot ID|Virtualization|Architecture"

    # 4. Server Uptime & Load
    print_header "4. Server Uptime & Load Average"
    uptime

    # 5. System Hardware Info
    print_header "5. System Hardware Info"
    echo -e "\n[+] Hardware Information (Summary):"
    if check_cmd lshw; then
        lshw -short 2>/dev/null | head -n 30
    else
        echo -e "${YELLOW}[!] 'lshw' command not found.${NC}"
    fi

    echo -e "\n[+] System Manufacturer Details:"
    if check_cmd dmidecode; then
        dmidecode -t system | grep -E "Manufacturer|Product Name|Serial Number" | sed 's/^[ \t]*//'
    fi

    # 6. Disk Usage Information
    print_header "6. Disk Usage Information"
    echo -e "\n[+] Disk Usage (Filesystems):"
    df -hT | column -t

    # Subtract 1 from wc -l to ignore the header row
    FS_COUNT=$(($(df -hT | wc -l) - 1))
    echo -e "\n[+] Total Mounted Filesystems Count: $FS_COUNT"

    echo -e "\n[+] ${YELLOW}Filesystems using more than 70%:${NC}"
    df -hP | awk 'NR==1 || $5+0 > 70' | column -t

    # 7. Filesystem Table
    print_header "7. Filesystem Table (/etc/fstab)"
    grep -v '^#' /etc/fstab | sed '/^$/d' | column -t

    # 8. Display Block Devices
    print_header "8. Block Devices (Disks and Partitions)"
    lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT | column -t

    # 9. LVM Details
    print_header "9. Logical Volume Management (LVM)"
    if check_cmd pvs && check_cmd vgs && check_cmd lvs; then
        echo -e "\n[+] Physical Volumes (PVs):"
        pvs
        echo -e "\n[+] Volume Groups (VGs):"
        vgs
        echo -e "\n[+] Logical Volumes (LVs):"
        lvs
    else
        echo -e "${YELLOW}[!] LVM commands not found or not applicable.${NC}"
    fi

    # 10. Network Interfaces & Routing
    print_header "10. Network Interfaces & Routing"
    echo -e "\n[+] Interfaces (Brief):"
    ip -br addr | column -t

    echo -e "\n[+] Link Statistics:"
    ip -s -h link

    echo -e "\n[+] Routing Table:"
    ip -4 route | column -t

    # 11. Firewall Status & Rules
    print_header "11. Firewall Status & Rules"
    if systemctl is-active --quiet firewalld; then
        echo -e "${GREEN}[+] Firewalld is ACTIVE${NC}"
        echo -e "\n[+] Active Zones and Ports:"
        firewall-cmd --list-all 2>/dev/null | grep -E "target|icmp-block-inversion|interfaces|services|ports|protocols"
    else
        echo -e "${RED}[-] Firewalld is INACTIVE or not running.${NC}"
    fi

    # 12. Open Ports (Listening)
    print_header "12. Open Ports (Listening)"
    ss -tulpn | column -t

    # 13. Key Services Status
    print_header "13. Key Services Status"
    
    echo -e "[+] Native System Services:"
    systemctl list-units --type=service --state=running | head -n 15

    # Splunk Check (Checks binary first, then systemctl/processes)
    echo -e "\n[+] SERVICES: (SEIM) Splunk Agent"
    if [ -f "/opt/splunkforwarder/bin/splunk" ]; then
        if /opt/splunkforwarder/bin/splunk status 2>/dev/null | grep -q "running"; then
            echo -e "${GREEN}[✔] Splunk Agent is running (Forwarder binary)${NC}"
        else
            echo -e "${RED}[✘] Splunk Agent found but not running.${NC}"
        fi
    elif systemctl is-active --quiet splunk || pgrep -f "splunkd" >/dev/null; then
        echo -e "${GREEN}[✔] Splunk Agent is running (System Service)${NC}"
    else
        echo -e "${RED}[✘] SPLUNK is not running/Present.${NC}"
    fi

    # Dynatrace Check
    echo -e "\n[+] SERVICES: (Dynatrace) OneAgent"
    if systemctl is-active --quiet oneagent; then
        echo -e "${GREEN}[✔] OneAgent is running${NC}"
    else
        echo -e "${RED}[✘] Oneagent is not running/Present.${NC}"
    fi

    # 14. Crontab Entry
    print_header "14. Root Crontab Entries"
    crontab -l 2>/dev/null || echo -e "No crontab for root."

    # 15. Running Processes
    print_header "15. Application Process Counts"

    echo -e "[+] Total System Processes : $(ps -eaf | wc -l)"

    # Using regex brackets (e.g. "[m]qm") prevents grep from counting its own process
    echo -e "[+] MQM Processes Count    : $(ps -eaf | grep -i "[m]qm" | wc -l)"
    echo -e "[+] GIT Processes Count    : $(ps -eaf | grep -i "[g]it" | wc -l)"
    
    echo -e "\n[+] DB (PMON) Processes:"
    ps -eaf | grep -i "[p]mon" || echo "No PMON processes found."
    echo -e "[+] DB (PMON) Count        : $(ps -eaf | grep -i "[p]mon" | wc -l)"

    echo -e "\n[+] DB Listener (TNS) Processes:"
    ps -eaf | grep -i "[t]ns" || echo "No TNS processes found."
    echo -e "[+] DB Listener (TNS) Count: $(ps -eaf | grep -i "[t]ns" | wc -l)"

    # 16. CPU & Memory Info
    print_header "16. System Resources (CPU & Memory)"
    echo -e "\n[+] CPU INFO:"
    lscpu | grep -E "Model name|Architecture|CPU\(s\):|Thread\(s\) per core|Core\(s\) per socket|Socket\(s\)" | column -t -s ':'

    echo -e "\n[+] MEMORY INFO:"
    free -mh | column -t

    echo -e "\n${GREEN}${BOLD}======================================================================${NC}"
    echo -e "${GREEN}${BOLD}                   PRE-CHECK COMPLETION SUCCESSFUL                    ${NC}"
    echo -e "${GREEN}${BOLD}======================================================================${NC}"
}

# Execute main function and pipe stdout/stderr synchronously to tee
main 2>&1 | tee "$LOG_FILE"
