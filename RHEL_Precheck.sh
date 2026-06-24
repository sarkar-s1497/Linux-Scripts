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
# Usage          : ./backup_logs.sh [target_directory]
# Notes          : Requires root privileges.
# ==============================================================================

# RHEL 9 System Pre-Check Script

# Helper function for section headers
print_header() {
  echo -e "\n==========================================================="
  echo -e " $1"
  echo -e "==========================================================="
}



# Check if run as root
if [ "$EUID" -ne 0 ]; then
  echo "[-] Please run as root (sudo)."
  exit 1
fi

echo "========================================="
echo "        RHEL 9 SYSTEM PRE-CHECK        "
echo "========================================="

echo "Hostname : $(hostname)"
echo "IP Address : $(hostname -I)"

# 1. View RHEL Version
print_header "1. View RHEL Version"
echo -e "\n[+] OS Version:"
sudo cat /etc/redhat-release


# 2. Kernel Release Version
print_header "2. Kernel Release Version"
echo -e "\n[+] Kernel Release:"
sudo uname -a

# 3. Server Hostname
print_header "3. Server Hostname"
echo -e "\n[+] Server Hostname:"
sudo hostnamectl

# 4. Server Uptime
print_header "4. Server Uptime"
echo -e "\n[+] Server Uptime:"
sudo uptime

# 5. System Hardware Info
print_header "5. System Hardware Info"
echo -e "\n[+] Hardware Information (Summary):"
sudo lshw -short 2>/dev/null | head -n 20
echo -e "\n"
sudo dmidecode -t system | grep -E "Manufacturer|Product Name|Serial Number"

# 6. Disk Usage Information
print_header "6. Disk Usage Information"
echo -e "\n[+] Disk Usage (Filesystems):"
sudo df -hT
echo -e "\n[+] Disk Usage (Filesystems using more than 70%):"
sudo df -h | awk 'NR>1 {gsub("%","",$5); if($5 > 70) print $0}'

# 7. Filesystem Table
print_header "7. Filesystem Table"
echo -e "\n[+] Filesystem Table (/etc/fstab):"
sudo cat /etc/fstab

# 8. Display Block Device
print_header "8. Display Block Device"
echo -e "\n[+] Block Devices (Disks and Partitions):"
sudo lsblk -o NAME,FSTYPE,SIZE,MOUNTPOINT

# 9. Physical Volume Details
print_header "9. Physical Volume Details"
echo -e "\n[+] LVM - Physical Volumes (PVs):"
sudo pvs

# 10. Volume Group Details
print_header "10. Volume Group Details"
echo -e "\n[+] LVM - Volume Groups (VGs):"
sudo vgs

# 11. Logical Volume Details
print_header "11. Logical Volume Details"
echo -e "\n[+] LVM - Logical Volumes (LVs):"
sudo lvs

# 12. Check Network Interfaces
print_header "12. Check Network Interfaces"
echo -e "\n[+] Network Interfaces:"
sudo ip -br addr
sudo ip -s -h link

# 13. View Route / IP Details
print_header "13. View Route / IP Details"
echo -e "\n[+] Routing Table:"
sudo ip -4 route

# 14. Firewall Status
print_header "14. Firewall Status"
echo -e "\n[+] Firewall Status:"
sudo systemctl status firewalld --no-pager

echo -e "\n=== FIREWALL PORTS (ACTIVE ZONES) ==="
sudo firewall-cmd --list-all 2>/dev/null || echo "Firewalld is not running."

# 15. Open Ports (Listening)
print_header "15. Open Ports (Listening)"
echo -e "\n[+] Open Listening Ports:"
sudo ss -tulpn


# 16. Running Services
print_header "16. RUNNING SERVICES"
echo -e "\n[+] RUNNING SERVICES:"
sudo systemctl list-units --type=service --state=running
 

#SEIM Splunk Agent
echo -e "\n[+] SERVICES: (SEIM) Splunk Agent"
sudo /opt/splunkforwarder/bin/splunk status | grep running || echo "SPLUNK is not running/Presnt."

#Dynatrace One-View
echo -e "\n[+] SERVICES: (Dynatrace) One-View"
sudo systemctl status oneagent | grep -E "Active|Main" || echo "Oneagent is not running/Present."




echo -e "\n[!] Precheck script execution completed."

echo "========================================="
echo "              CHECK COMPLETE             "
echo "========================================="
