#!/bin/bash

# ==============================================================================
# Script Name    : RHEL_Precheck.sh
# Description    : This Take precheck of the system.
# Author         : Sujit Sarkar
# Email          :
# Version        : 1.0.0
# Date Created   : 2026-06-24
# Last Modified  : 2026-06-24
# ==============================================================================
# Directory/File : scripts/log/Precheck_$(hostname)_$(date +%F_%H-%M-%S).txt 
# Notes          : Requires root privileges.
# ==============================================================================

# --- COLOR DEFINITIONS ---
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# RHEL 9 System Pre-Check Script

# Helper function for section headers
print_header() {
  echo -e "\n${CYAN}===========================================================${NC}"
  echo -e "${CYAN} $1${NC}"
  echo -e "${CYAN}===========================================================${NC}"
}

# Check if run as root
if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}[-] Please run as root (sudo).${NC}"
  exit 1
fi

# Ensure the log directory exists
mkdir -p /scripts/log

# Auto-save all output to /scripts/log with hostname, date and time
# Note: I added '2>&1' to ensure system errors are also saved to your log file
exec > "/scripts/log/Precheck_$(hostname)_$(date +%F_%H-%M-%S).txt" 2>&1

echo "========================================="
echo "        RHEL 9 SYSTEM PRE-CHECK        "
echo "========================================="

echo "Hostname : $(hostname)"
echo "IP Address : $(hostname -I)"

# 1. View RHEL Version
print_header "1. View RHEL Version"
echo -e "\n[+] OS Version:"
cat /etc/redhat-release

# 2. Kernel Release Version
print_header "2. Kernel Release Version"
echo -e "\n[+] Kernel Release:"
uname -a

# 3. Server Hostname
print_header "3. Server Hostname"
echo -e "\n[+] Server Hostname:"
hostnamectl

# 4. Server Uptime
print_header "4. Server Uptime"
echo -e "\n[+] Server Uptime:"
uptime

# 5. System Hardware Info
print_header "5. System Hardware Info"
echo -e "\n[+] Hardware Information (Summary):"
lshw -short 2>/dev/null | head -n 30
echo -e "\n"
dmidecode -t system | grep -E "Manufacturer|Product Name|Serial Number"

# 6. Disk Usage Information
print_header "6. Disk Usage Information"
echo -e "\n[+] Disk Usage (Filesystems):"
df -hT
echo -e "\n[+] Disk Usage (Filesystems using more than 70%):"
df -hP | awk 'NR==1 || $5+0 >70'

# 7. Filesystem Table
print_header "7. Filesystem Table"
echo -e "\n[+] Filesystem Table (/etc/fstab):"
cat /etc/fstab

# 8. Display Block Device
print_header "8. Display Block Device"
echo -e "\n[+] Block Devices (Disks and Partitions):"
lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT

# 9. Physical Volume Details
print_header "9. Physical Volume Details"
echo -e "\n[+] LVM - Physical Volumes (PVs):"
pvs

# 10. Volume Group Details
print_header "10. Volume Group Details"
echo -e "\n[+] LVM - Volume Groups (VGs):"
vgs

# 11. Logical Volume Details
print_header "11. Logical Volume Details"
echo -e "\n[+] LVM - Logical Volumes (LVs):"
lvs

# 12. Check Network Interfaces
print_header "12. Check Network Interfaces"
echo -e "\n[+] Network Interfaces:"
ip -br addr
echo -e "\n\n"
ip -s -h link

# 13. View Route / IP Details
print_header "13. View Route / IP Details"
echo -e "\n[+] Routing Table:"
ip -4 route

# 14. Firewall Status
print_header "14. Firewall Status"
echo -e "\n[+] Firewall Status:"
systemctl status firewalld --no-pager 2>/dev/null | grep -E "Active|Main"

echo -e "\n=== FIREWALL PORTS (ACTIVE ZONES) ==="
firewall-cmd --list-all 2>/dev/null || echo -e "${RED}Firewalld is not running.${NC}"

# 15. Open Ports (Listening)
print_header "15. Open Ports (Listening)"
echo -e "\n[+] Open Listening Ports:"
ss -tulpn

# 16. Running Services
print_header "16. RUNNING SERVICES"
echo -e "\n[+] RUNNING SERVICES:"
systemctl list-units --type=service --state=running
 
# SEIM Splunk Agent
echo -e "\n[+] SERVICES: (SEIM) Splunk Agent"
/opt/splunkforwarder/bin/splunk status 2>/dev/null | grep running || echo -e "${RED}SPLUNK is not running/Present.${NC}"

# Dynatrace One-View
echo -e "\n[+] SERVICES: (Dynatrace) One-View"
systemctl status oneagent 2>/dev/null | grep -E "Active|Main" || echo -e "${RED}Oneagent is not running/Present.${NC}"

echo -e "\n[!] Precheck script execution completed."

echo "========================================="
echo "              CHECK COMPLETE             "
echo "========================================="
