#!/bin/bash
# monitoring.sh
# Born2beRoot - system monitoring script
# Broadcasts system info to all terminals at boot and every 10 minutes (via cron + wall).

# ----------------------------------------------------------------------------
# Redirect any stderr to /dev/null so no errors are ever displayed (subject rule)
# ----------------------------------------------------------------------------
exec 2>/dev/null

# ----------------------------------------------------------------------------
# 1. Architecture & kernel version
# ----------------------------------------------------------------------------
arch=$(uname -a)

# ----------------------------------------------------------------------------
# 2. Physical CPU count (unique physical id entries)
# ----------------------------------------------------------------------------
phys_cpu=$(grep "physical id" /proc/cpuinfo | sort -u | wc -l)
# Fallback: if no "physical id" field (some VMs), treat as 1
[ "$phys_cpu" -eq 0 ] && phys_cpu=1

# ----------------------------------------------------------------------------
# 3. Virtual CPU count (logical processors)
# ----------------------------------------------------------------------------
vcpu=$(grep -c "^processor" /proc/cpuinfo)

# ----------------------------------------------------------------------------
# 4. Memory usage (used / total in MB + percentage)
#    MemTotal and MemAvailable are in kB in /proc/meminfo
# ----------------------------------------------------------------------------
mem_total_kb=$(grep "MemTotal" /proc/meminfo | awk '{print $2}')
mem_avail_kb=$(grep "MemAvailable" /proc/meminfo | awk '{print $2}')
mem_used_kb=$((mem_total_kb - mem_avail_kb))

mem_info=$(awk -v used="$mem_used_kb" -v total="$mem_total_kb" 'BEGIN {
    used_mb = used / 1024
    total_mb = total / 1024
    pct = (used / total) * 100
    printf "%d/%dMB (%.2f%%)", used_mb, total_mb, pct
}')

# ----------------------------------------------------------------------------
# 5. Disk usage (used / total on root partition + percentage)
# ----------------------------------------------------------------------------
disk_info=$(df -h / | awk 'NR==2 {
    used=$3
    total=$2
    pct=$5
    gsub(/%/, "", pct)
    printf "%s/%sb (%d%%)", used, total, pct
}')

# ----------------------------------------------------------------------------
# 6. CPU load percentage (100 - idle)
#    top -bn1 -> "Cpu(s):  x.x us, ... , y.y id"
# ----------------------------------------------------------------------------
cpu_load=$(top -bn1 | grep "Cpu(s)" | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100 - $1}')
# Round to 1 decimal
cpu_load=$(awk -v v="$cpu_load" 'BEGIN { printf "%.1f", v }')

# ----------------------------------------------------------------------------
# 7. Last boot date & time
# ----------------------------------------------------------------------------
last_boot=$(who -b | awk '{print $3" "$4}')

# ----------------------------------------------------------------------------
# 8. LVM active?
# ----------------------------------------------------------------------------
if lsblk | grep -q "lvm"; then
    lvm_use="yes"
else
    lvm_use="no"
fi

# ----------------------------------------------------------------------------
# 9. TCP connections in ESTABLISHED state
#    /proc/net/tcp: state 01 == ESTABLISHED
# ----------------------------------------------------------------------------
tcp_est=$(grep -c " 01 " /proc/net/tcp)

# ----------------------------------------------------------------------------
# 10. Number of users logged in
# ----------------------------------------------------------------------------
user_log=$(who | awk '{print $1}' | sort -u | wc -l)

# ----------------------------------------------------------------------------
# 11. IPv4 address + MAC address of the default interface
# ----------------------------------------------------------------------------
iface=$(ip route | awk '/default/ {print $5; exit}')
ipv4=$(ip -4 addr show "$iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
mac=$(ip link show "$iface" | grep -oP '(?<=link/ether\s)[0-9a-f:]+')

# ----------------------------------------------------------------------------
# 12. Number of commands executed with sudo
#     sudo is configured to log to /var/log/sudo/ (see sudoers config)
# ----------------------------------------------------------------------------
if [ -d /var/log/sudo ]; then
    sudo_cmd=$(grep -rh "COMMAND" /var/log/sudo/ 2>/dev/null | wc -l)
else
    sudo_cmd=0
fi

# ----------------------------------------------------------------------------
# Build the message
# ----------------------------------------------------------------------------
msg="#Architecture: $arch
#Physical CPU: $phys_cpu
#vCPU: $vcpu
#Memory Usage: $mem_info
#Disk Usage: $disk_info
#CPU load: $cpu_load%
#Last boot: $last_boot
#LVM use: $lvm_use
#TCP Connections: $tcp_est ESTABLISHED
#User log: $user_log
#Network: IP $ipv4 ($mac)
#Sudo: $sudo_cmd cmd"

# ----------------------------------------------------------------------------
# Broadcast to all terminals (wall adds the "Broadcast message" header)
# ----------------------------------------------------------------------------
echo "$msg" | wall
