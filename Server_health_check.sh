#!/bin/bash
# ==============================================================================
# Script Name    : Server_Health_Check.sh
# Author         : Sujit Sarkar
# Email          :
# Version        : 1.0.0
# ENTERPRISE RHEL 8 / RHEL 9 HEALTH CHECK & AUDIT SCRIPT
# Compatibility: RHEL 8.x, RHEL 9.x
# Features: Dynamic Thresholds, Security Audits, Network Status, Chrony Sync,
#           Top Processes, Clean ANSI Visual Output.
# ==============================================================================

# --- CONFIGURATION THRESHOLDS ---
CPU_WARN=75
MEM_WARN=75
DISK_WARN=70

# Ensure script is run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "\e[1;31m[ERROR] This script must be run with root privileges.\e[0m"
  exit 1
fi

# Define Report Output
DATE=$(date +'%Y-%m-%d_%H-%M-%S')
LOG_DIR="/scripts/log"
REPORT_FILE="$LOG_DIR/server_health_log_$(hostname)_$(date +%F_%H-%M-%S).txt"
mkdir -p "$LOG_DIR"

# ANSI Colors
NC='\033[0m'
BOLD='\033[1m'
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
CYAN='\033[1;36m'
WHITE='\033[1;37m'

# --- HELPER FUNCTIONS ---
print_banner() {
    echo -e "${BLUE}================================================================${NC}"
    echo -e "${BLUE}  $1 ${NC}"
    echo -e "${BLUE}================================================================${NC}"
}


print_status() {
    local label="$1"
    local value="$2"
    local status="$3" # OK, WARN, CRIT
    case "$status" in
        "OK")   printf "   %-35s : [ ${GREEN}OK${NC} ] (%s)\n" "$label" "$value" ;;
        "WARN") printf "   %-35s : [ ${YELLOW}WARN${NC} ] (%s)\n" "$label" "$value" ;;
        "CRIT") printf "   %-35s : [ ${RED}CRITICAL${NC} ] (%s)\n" "$label" "$value" ;;
        *)      printf "   %-35s : (%s)\n" "$label" "$value" ;;
    esac
}



# Redirect all stdout and stderr to console and log file
exec > >(tee -a "$REPORT_FILE") 2>&1

echo -e "${CYAN}${BOLD}Executing Health Check on $(hostname) - $(date)${NC}\n"

# ==========================================
# 1. SYSTEM IDENTITY & UPTIME
# ==========================================
print_banner "1. SYSTEM PROFILE & UPTIME"

echo -e "   Date            : $(date)"
echo -e "   Hostname        : $(hostname)"
echo -e "   OS Release      : $(cat /etc/redhat-release)"
echo -e "   Kernel Architecture: $(uname -r) ($(uname -m))"
echo -e "   System Uptime   : $(uptime -p | sed 's/up //')"
echo -e "   Boot Time       : $(who -b | awk '{print $3" "$4}')"

# ==========================================
# 2. DYNAMIC RESOURCE MONITORING
# ==========================================
print_banner "2. RESOURCE UTILIZATION & THRESHOLDS"

# CPU Load Check
CPU_IDLE=$(top -bn1 | grep "Cpu(s)" | awk '{print $8}')
CPU_USAGE=$(echo "100 - $CPU_IDLE" | bc 2>/dev/null || awk "BEGIN {print 100 - $CPU_IDLE}")
CPU_INT=${CPU_USAGE%.*}

if [ "$CPU_INT" -gt "$CPU_WARN" ]; then
    print_status "Overall CPU Utilization" "${CPU_USAGE}%" "CRIT"
else
    print_status "Overall CPU Utilization" "${CPU_USAGE}%" "OK"
fi

# Memory Check
MEM_TOTAL=$(free | grep Mem | awk '{print $2}')
MEM_USED=$(free | grep Mem | awk '{print $3}')
MEM_PCT=$((100 * MEM_USED / MEM_TOTAL))

if [ "$MEM_PCT" -gt "$MEM_WARN" ]; then
    print_status "Memory Utilization" "${MEM_PCT}%" "WARN"
else
    print_status "Memory Utilization" "${MEM_PCT}%" "OK"
fi

# Swap Check
SWAP_TOTAL=$(free | grep Swap | awk '{print $2}')
if [ "$SWAP_TOTAL" -gt 0 ]; then
    SWAP_USED=$(free | grep Swap | awk '{print $3}')
    SWAP_PCT=$((100 * SWAP_USED / SWAP_TOTAL))
    if [ "$SWAP_PCT" -gt 50 ]; then
        print_status "Swap Utilization" "${SWAP_PCT}%" "WARN"
    else
        print_status "Swap Utilization" "${SWAP_PCT}%" "OK"
    fi
else
    print_status "Swap Space" "Not configured/disabled" "OK"
fi

# ==========================================
# 3. DISK & STORAGE SANITY
# ==========================================
print_banner "3. STORAGE & MOUNT HEALTH"
echo -e "   Checking local filesystems for space (> ${DISK_WARN}% critical limit):"
df -hP -x tmpfs -x devtmpfs | grep -v '^Filesystem' | while read -r line; do
    USAGE_PCT=$(echo "$line" | awk '{print $5}' | sed 's/%//')
    MOUNT_PT=$(echo "$line" | awk '{print $6}')
    if [ "$USAGE_PCT" -gt "$DISK_WARN" ]; then
        echo -e "   - Mount: ${MOUNT_PT} is at ${RED}${USAGE_PCT}%${NC} utilization!"
    else
        echo -e "   - Mount: ${MOUNT_PT} [ ${GREEN}${USAGE_PCT}%${NC} ]"
    fi
done

# Read-only Filesystem Audit
RO_MOUNTS=$(mount | grep -E '\sro[\s,]')
if [ -z "$RO_MOUNTS" ]; then
    print_status "Read-Only Mounts Audit" "No unintended RO filesystems found" "OK"
else
    print_status "Read-Only Mounts Audit" "CRITICAL - RO mount detected" "CRIT"
    echo "$RO_MOUNTS" | sed 's/^/    /'
fi

# ==========================================
# 4. OS HARDENING & SECURITY METRICS
# ==========================================
print_banner "4. SECURITY & AUDITING ENVIRONMENT"

# SELinux Status
SE_STATUS=$(getenforce)
if [ "$SE_STATUS" = "Enforcing" ]; then
    print_status "SELinux State" "Enforcing" "OK"
else
    print_status "SELinux State" "$SE_STATUS" "WARN"
fi

# Failed SSH Logins (Last 24 hrs)
FAILED_SSH=$(journalctl _SYSTEMD_UNIT=sshd.service --since "24 hours ago" | grep -c "Failed password")
if [ "$FAILED_SSH" -gt 20 ]; then
    print_status "Failed SSH Logins (24h)" "$FAILED_SSH spikes detected" "WARN"
else
    print_status "Failed SSH Logins (24h)" "$FAILED_SSH failures recorded" "OK"
fi

# Failed Sudo Attempts
FAILED_SUDO=$(journalctl --since "24 hours ago" | grep -c "auth failure\|COMMAND=")
print_status "Sudo Privilege Elevation Failures" "$FAILED_SUDO attempts" "OK"

echo -e "\n"

# Firewall Status
echo -e "\n[+] FIREWALL SERVICES:"
systemctl status firewalld --no-pager 2>/dev/null | grep -E "Active|Main"

# ==========================================
# 5. CORE SYSTEMD & NETWORK CHECKS
# ==========================================
print_banner "5. CORE SERVICES & NETWORKING"

# Chrony / Time Sync Status
if systemctl is-active --quiet chronyd; then
    CHRONY_TRACK=$(chronyc tracking | grep "Stratum" | awk '{print "Stratum " $3}')
    print_status "NTP Sync (chronyd)" "Active ($CHRONY_TRACK)" "OK"
else
    print_status "NTP Sync (chronyd)" "Inactive/Stopped" "CRIT"
fi


# Network Connection Counts
EST_CONN=$(ss -ant | grep -c ESTAB)
echo -e "   Established Network Connections: $EST_CONN"


# ==========================================
# 6. TOP RESOURCE CONSUMERS
# ==========================================
print_banner "6. PROCESS RESOURCE TRIAGE"
echo -e "   Top 5 Processes by CPU Overhead:"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%cpu | head -n 6 | sed 's/^/    /'

echo -e "\n   Top 5 Processes by Memory Footprint:"
ps -eo pid,ppid,cmd,%cpu,%mem --sort=-%mem | head -n 6 | sed 's/^/    /'


# ==========================================
# 7. Running Services
# ==========================================
print_banner "7. All Core Running Services"

# SEIM Splunk Agent
echo -e "\n[+] SERVICES: (SEIM) Splunk Agent"
/opt/splunkforwarder/bin/splunk status 2>/dev/null | grep running || echo -e "${RED}SPLUNK is not running/Present.${NC}"

# Dynatrace One-View
echo -e "\n[+] SERVICES: (Dynatrace) One-View"
systemctl status oneagent 2>/dev/null | grep -E "Active|Main" || echo -e "${RED}Oneagent is not running/Present.${NC}"

# Running Services
echo -e "\n[+] RUNNING SERVICES:"
systemctl list-units --type=service --state=running



echo -e "\n${BLUE}================================================================${NC}"
echo -e "${GREEN}${BOLD} Diagnostic complete. Clean report generated at: ${REPORT_FILE}${NC}"
echo -e "${BLUE}================================================================${NC}"
