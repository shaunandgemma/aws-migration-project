#!/bin/bash

# ============================================================
# Linux Migration Discovery Script
# Purpose: Read-only technical discovery for migration planning
#
# Collects:
# - OS / hardware
# - CPU / memory / swap
# - disks / filesystems / LVM / RAID / multipath
# - networking / routes / DNS / active connections
# - listening ports
# - remote storage
# - running and enabled services
# - common application/database/container software
# - firewalls / AppArmor / SELinux
# - cron / systemd timers
# - web server information
# - NFS / Samba / iSCSI
# - package versions
# - custom application/service indicators
#
# Does NOT intentionally read:
# - passwords
# - private keys
# - environment-file contents
# - database credentials
# ============================================================

set +e

if [ "$EUID" -ne 0 ]; then
    echo "Please run this script with sudo."
    exit 1
fi

TMPDIR=$(mktemp -d)
trap 'rm -rf "$TMPDIR"' EXIT

HOSTNAME=$(hostname)
DISCOVERY_DATE=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
PRIMARY_USER="${SUDO_USER:-root}"

capture() {
    FILE="$1"
    shift
    "$@" > "$TMPDIR/$FILE" 2>&1
}

capture_shell() {
    FILE="$1"
    shift
    bash -c "$*" > "$TMPDIR/$FILE" 2>&1
}

section() {
    echo
    echo "============================================================"
    echo " $1"
    echo "============================================================"

    if [ -s "$2" ]; then
        cat "$2"
    else
        echo "No output returned / command not available."
    fi
}

# ============================================================
# BASIC SYSTEM DISCOVERY
# ============================================================

capture hostname.txt hostnamectl
capture cpu.txt lscpu
capture memory.txt free -h
capture uptime.txt uptime
capture kernel.txt uname -a

capture_shell users.txt \
"getent passwd | awk -F: '\$3 >= 1000 && \$1 != \"nobody\" {print \$1, \"UID=\"\$3, \"Home=\"\$6, \"Shell=\"\$7}'"

# ============================================================
# STORAGE DISCOVERY
# ============================================================

capture disks.txt lsblk -o NAME,SIZE,TYPE,FSTYPE,FSVER,MOUNTPOINTS
capture filesystem.txt df -hT
capture inode.txt df -hi
capture blkid.txt blkid

if command -v pvs >/dev/null 2>&1; then
    capture pvs.txt pvs
    capture vgs.txt vgs
    capture lvs.txt lvs
else
    echo "LVM tools not installed." > "$TMPDIR/pvs.txt"
    cp "$TMPDIR/pvs.txt" "$TMPDIR/vgs.txt"
    cp "$TMPDIR/pvs.txt" "$TMPDIR/lvs.txt"
fi

if command -v mdadm >/dev/null 2>&1; then
    capture_shell raid.txt "cat /proc/mdstat; echo; mdadm --detail --scan"
else
    capture_shell raid.txt "cat /proc/mdstat 2>/dev/null"
fi

if command -v multipath >/dev/null 2>&1; then
    capture multipath.txt multipath -ll
else
    echo "Multipath command not installed." > "$TMPDIR/multipath.txt"
fi

# ============================================================
# NETWORK DISCOVERY
# ============================================================

capture interfaces.txt ip -br addr
capture routes.txt ip route
capture ipv6-routes.txt ip -6 route
capture neighbours.txt ip neigh
capture listening.txt ss -tulpn
capture connections.txt ss -tunap

capture_shell dns.txt \
"echo '--- resolv.conf ---'; cat /etc/resolv.conf 2>/dev/null; \
 echo; echo '--- resolvectl ---'; resolvectl status 2>/dev/null"

if command -v nmcli >/dev/null 2>&1; then
    capture networkmanager.txt nmcli connection show
else
    echo "NetworkManager/nmcli not installed." > "$TMPDIR/networkmanager.txt"
fi

# ============================================================
# FILESYSTEM / REMOTE STORAGE DEPENDENCIES
# ============================================================

capture mounts.txt findmnt
capture_shell remote-mounts.txt \
"findmnt -rn -t nfs,nfs4,cifs,fuse.sshfs -o SOURCE,TARGET,FSTYPE,OPTIONS 2>/dev/null"

capture_shell fstab.txt \
"grep -vE '^[[:space:]]*#|^[[:space:]]*$' /etc/fstab 2>/dev/null"

capture_shell exports.txt \
"grep -vE '^[[:space:]]*#|^[[:space:]]*$' /etc/exports 2>/dev/null"

if command -v showmount >/dev/null 2>&1; then
    capture_shell nfs-exports.txt "exportfs -v 2>/dev/null"
else
    echo "NFS export tools not installed." > "$TMPDIR/nfs-exports.txt"
fi

if command -v smbstatus >/dev/null 2>&1; then
    capture samba-status.txt smbstatus
else
    echo "Samba not detected." > "$TMPDIR/samba-status.txt"
fi

capture_shell samba-shares.txt \
"if [ -f /etc/samba/smb.conf ]; then \
 grep -E '^[[:space:]]*\[[^]]+\]' /etc/samba/smb.conf; \
 else echo 'No Samba configuration found.'; fi"

if command -v iscsiadm >/dev/null 2>&1; then
    capture_shell iscsi.txt \
    "iscsiadm -m session 2>/dev/null; echo; iscsiadm -m node 2>/dev/null"
else
    echo "iSCSI tools not installed." > "$TMPDIR/iscsi.txt"
fi

# ============================================================
# SERVICE DISCOVERY
# ============================================================

capture services-running.txt \
systemctl --type=service --state=running --no-pager

capture services-enabled.txt \
systemctl list-unit-files --type=service --state=enabled --no-pager

capture_shell failed-services.txt \
"systemctl --failed --no-pager"

capture_shell custom-services.txt \
"find /etc/systemd/system -maxdepth 1 -type f -name '*.service' -printf '%f\n' 2>/dev/null"

# ============================================================
# SCHEDULED TASKS
# ============================================================

capture timers.txt systemctl list-timers --all --no-pager

capture_shell user-cron.txt \
"sudo -u '$PRIMARY_USER' crontab -l 2>&1"

capture_shell root-cron.txt \
"crontab -l 2>&1"

capture_shell cron-files.txt \
"echo '--- /etc/cron.d ---'; ls -la /etc/cron.d 2>/dev/null; \
 echo; echo '--- cron.daily ---'; ls -la /etc/cron.daily 2>/dev/null; \
 echo; echo '--- cron.hourly ---'; ls -la /etc/cron.hourly 2>/dev/null; \
 echo; echo '--- cron.weekly ---'; ls -la /etc/cron.weekly 2>/dev/null; \
 echo; echo '--- cron.monthly ---'; ls -la /etc/cron.monthly 2>/dev/null"

# ============================================================
# FIREWALL / SECURITY DISCOVERY
# ============================================================

if command -v ufw >/dev/null 2>&1; then
    capture ufw.txt ufw status verbose
else
    echo "UFW not installed." > "$TMPDIR/ufw.txt"
fi

if command -v nft >/dev/null 2>&1; then
    capture nftables.txt nft list ruleset
else
    echo "nftables command not installed." > "$TMPDIR/nftables.txt"
fi

if command -v iptables >/dev/null 2>&1; then
    capture iptables.txt iptables -L -n -v
else
    echo "iptables command not installed." > "$TMPDIR/iptables.txt"
fi

if command -v ip6tables >/dev/null 2>&1; then
    capture ip6tables.txt ip6tables -L -n -v
else
    echo "ip6tables command not installed." > "$TMPDIR/ip6tables.txt"
fi

if command -v firewall-cmd >/dev/null 2>&1; then
    capture_shell firewalld.txt \
    "firewall-cmd --state 2>&1; firewall-cmd --list-all 2>&1"
else
    echo "firewalld not installed." > "$TMPDIR/firewalld.txt"
fi

if command -v aa-status >/dev/null 2>&1; then
    capture apparmor.txt aa-status
else
    echo "AppArmor tools not installed." > "$TMPDIR/apparmor.txt"
fi

if command -v getenforce >/dev/null 2>&1; then
    capture selinux.txt getenforce
else
    echo "SELinux tools not installed." > "$TMPDIR/selinux.txt"
fi

capture_shell ssh-security.txt \
"if command -v sshd >/dev/null 2>&1; then \
 sshd -T 2>/dev/null | grep -Ei \
 '^(port|listenaddress|permitrootlogin|passwordauthentication|pubkeyauthentication|maxauthtries|allowusers|allowgroups)'; \
 else echo 'sshd not installed.'; fi"

# ============================================================
# WEB SERVER DISCOVERY
# ============================================================

if command -v nginx >/dev/null 2>&1; then
    capture_shell nginx-version.txt "nginx -v 2>&1"

    capture_shell nginx-sites.txt \
    "find /etc/nginx -maxdepth 3 -type f \
    \( -name '*.conf' -o -path '*/sites-enabled/*' \) \
    -print 2>/dev/null"

    capture_shell nginx-routing.txt \
    "grep -R -nE \
    '^[[:space:]]*(listen|server_name|proxy_pass|upstream|root)[[:space:]]' \
    /etc/nginx 2>/dev/null"
else
    echo "Nginx not detected." > "$TMPDIR/nginx-version.txt"
    cp "$TMPDIR/nginx-version.txt" "$TMPDIR/nginx-sites.txt"
    cp "$TMPDIR/nginx-version.txt" "$TMPDIR/nginx-routing.txt"
fi

if command -v apache2ctl >/dev/null 2>&1; then
    capture apache-version.txt apache2ctl -v
    capture apache-sites.txt apache2ctl -S
    capture apache-modules.txt apache2ctl -M
elif command -v httpd >/dev/null 2>&1; then
    capture_shell apache-version.txt "httpd -v"
    capture_shell apache-sites.txt "httpd -S"
    capture_shell apache-modules.txt "httpd -M"
else
    echo "Apache not detected." > "$TMPDIR/apache-version.txt"
    cp "$TMPDIR/apache-version.txt" "$TMPDIR/apache-sites.txt"
    cp "$TMPDIR/apache-version.txt" "$TMPDIR/apache-modules.txt"
fi

# ============================================================
# DATABASE SOFTWARE DISCOVERY
# No login to databases is attempted.
# ============================================================

capture_shell database-software.txt "
for CMD in mysql mariadb psql postgres redis-server mongod sqlplus; do
    if command -v \$CMD >/dev/null 2>&1; then
        echo \"--- \$CMD ---\"
        \$CMD --version 2>&1 | head -3
        echo
    fi
done
"

capture_shell database-services.txt \
"systemctl --type=service --all --no-pager | \
grep -Ei 'mysql|mariadb|postgres|mongodb|redis|oracle|mssql'"

# ============================================================
# CONTAINER / KUBERNETES DISCOVERY
# ============================================================

if command -v docker >/dev/null 2>&1; then
    capture docker-version.txt docker version
    capture docker-containers.txt docker ps -a
    capture docker-images.txt docker images
    capture docker-networks.txt docker network ls
    capture docker-volumes.txt docker volume ls
else
    echo "Docker not detected." > "$TMPDIR/docker-version.txt"
    cp "$TMPDIR/docker-version.txt" "$TMPDIR/docker-containers.txt"
    cp "$TMPDIR/docker-version.txt" "$TMPDIR/docker-images.txt"
    cp "$TMPDIR/docker-version.txt" "$TMPDIR/docker-networks.txt"
    cp "$TMPDIR/docker-version.txt" "$TMPDIR/docker-volumes.txt"
fi

if command -v containerd >/dev/null 2>&1; then
    capture_shell containerd.txt "containerd --version"
else
    echo "containerd not detected." > "$TMPDIR/containerd.txt"
fi

if command -v kubectl >/dev/null 2>&1; then
    capture_shell kubernetes.txt \
    "kubectl version --client 2>/dev/null; \
     echo; kubectl config current-context 2>/dev/null"
else
    echo "kubectl not detected." > "$TMPDIR/kubernetes.txt"
fi

# ============================================================
# COMMON RUNTIMES / LANGUAGE DISCOVERY
# ============================================================

capture_shell runtimes.txt "
for CMD in \
python3 python \
php \
java \
node \
npm \
ruby \
perl \
go \
dotnet \
gunicorn \
uwsgi; do

    if command -v \$CMD >/dev/null 2>&1; then
        echo \"--- \$CMD ---\"
        \$CMD --version 2>&1 | head -3
        echo
    fi
done
"

# ============================================================
# PACKAGE DISCOVERY
# ============================================================

if command -v dpkg-query >/dev/null 2>&1; then
    capture_shell packages.txt \
    "dpkg-query -W -f='\${Package}\t\${Version}\n' 2>/dev/null | \
     grep -Ei \
     'nginx|apache|mysql|maria|postgres|python|gunicorn|uwsgi|php|java|tomcat|nodejs|docker|containerd|kube|nfs|samba|redis|mongodb|iscsi|multipath'"
elif command -v rpm >/dev/null 2>&1; then
    capture_shell packages.txt \
    "rpm -qa | grep -Ei \
     'nginx|httpd|mysql|maria|postgres|python|gunicorn|uwsgi|php|java|tomcat|nodejs|docker|containerd|kube|nfs|samba|redis|mongodb|iscsi|multipath'"
else
    echo "Supported package manager not detected." > "$TMPDIR/packages.txt"
fi

# ============================================================
# POSSIBLE APPLICATION LOCATIONS
# ============================================================

capture_shell app-dirs.txt \
"find /opt /srv /var/www /usr/local \
-maxdepth 3 \
-type d \
2>/dev/null | sort"

# Only metadata — no environment-file contents
capture_shell env-files.txt \
"find /opt /srv /var/www /etc \
-maxdepth 4 \
-type f \
\( -name '*.env' -o -name '.env' -o -name '*environment*' \) \
-exec ls -l {} \; \
2>/dev/null"

# ============================================================
# CERTIFICATE DISCOVERY
# Public certificate metadata only — never private-key contents
# ============================================================

capture_shell certificates.txt '
find /etc/ssl /etc/letsencrypt \
-type f \
\( -name "*.crt" -o -name "*.pem" \) \
2>/dev/null |
while read CERT; do
    if openssl x509 -in "$CERT" -noout >/dev/null 2>&1; then
        echo "File: $CERT"
        openssl x509 -in "$CERT" \
            -noout \
            -subject \
            -issuer \
            -dates 2>/dev/null
        echo
    fi
done
'

# ============================================================
# LOG / HEALTH DISCOVERY
# ============================================================

capture failed.txt systemctl --failed --no-pager

capture_shell kernel-errors.txt \
"journalctl -p err -b --no-pager -n 100 2>/dev/null"

capture_shell reboot-required.txt \
"if [ -f /var/run/reboot-required ]; then \
 cat /var/run/reboot-required; \
 else echo 'No reboot currently required.'; fi"

# ============================================================
# BUILD SUMMARY
# ============================================================

OS=$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null |
cut -d= -f2- | tr -d '"')

CPU_COUNT=$(nproc 2>/dev/null)
RAM=$(free -h | awk '/^Mem:/ {print $2}')
SWAP=$(free -h | awk '/^Swap:/ {print $2}')
ROOT_SIZE=$(df -h / | awk 'NR==2 {print $2}')
ROOT_USED=$(df -h / | awk 'NR==2 {print $3}')
ROOT_PERCENT=$(df -h / | awk 'NR==2 {print $5}')

DISKS=$(lsblk -dn -o NAME,SIZE,TYPE |
awk '$3=="disk" {print $1 " = " $2}')

DEFAULT_ROUTE=$(ip route show default | head -1)

IP_ADDRESSES=$(ip -4 -br addr |
awk '$1 != "lo" {print $1 " = " $3}')

REMOTE_MOUNTS=$(findmnt -rn \
-t nfs,nfs4,cifs,fuse.sshfs \
-o SOURCE,TARGET,FSTYPE 2>/dev/null)

# ============================================================
# SUMMARY OUTPUT
# ============================================================

echo "============================================================"
echo " MIGRATION DISCOVERY SUMMARY"
echo "============================================================"
echo
echo "Discovery date:   $DISCOVERY_DATE"
echo "Hostname:         $HOSTNAME"
echo "Operating OS:     $OS"
echo "CPU:              $CPU_COUNT vCPU(s)"
echo "RAM:              $RAM"
echo "Swap:             $SWAP"
echo "Root filesystem:  $ROOT_SIZE"
echo "Root used:        $ROOT_USED ($ROOT_PERCENT)"
echo

echo "ATTACHED DISKS"
echo "--------------"
echo "$DISKS"
echo

echo "NETWORK INTERFACES"
echo "------------------"
echo "$IP_ADDRESSES"
echo
echo "Default route:"
echo "$DEFAULT_ROUTE"
echo

echo "REMOTE FILESYSTEM DEPENDENCIES"
echo "------------------------------"

if [ -n "$REMOTE_MOUNTS" ]; then
    echo "$REMOTE_MOUNTS"
else
    echo "No NFS/CIFS/SSHFS remote mounts detected."
fi

echo
echo "APPLICATION / INFRASTRUCTURE SERVICES DETECTED"
echo "----------------------------------------------"

grep -Ei \
'nginx|apache|mysql|mariadb|postgres|gunicorn|docker|containerd|kube|nfs|samba|redis|mongodb|ssh|legacy' \
"$TMPDIR/services-running.txt" ||
echo "No common application services automatically identified."

echo
echo "LISTENING TCP PORTS"
echo "-------------------"

ss -ltnH |
awk '{print $4}' |
sort -u

echo
echo "============================================================"
echo " MIGRATION FLAGS / ITEMS TO INVESTIGATE"
echo "============================================================"
echo

ROOT_NUMBER=$(echo "$ROOT_PERCENT" | tr -d '%')

if [ "$ROOT_NUMBER" -ge 80 ] 2>/dev/null; then
    echo "[RISK] Root filesystem utilisation is $ROOT_PERCENT."
else
    echo "[INFO] Root filesystem utilisation is $ROOT_PERCENT."
fi

if [ -n "$REMOTE_MOUNTS" ]; then
    echo "[DEPENDENCY] Remote filesystem mounts detected."
fi

if grep -qi "Status: inactive" "$TMPDIR/ufw.txt"; then
    echo "[SECURITY] UFW is inactive."
fi

if grep -qi "not installed" "$TMPDIR/ufw.txt"; then
    echo "[INFO] UFW is not installed."
fi

if [ ! -s "$TMPDIR/nftables.txt" ]; then
    echo "[SECURITY] No nftables rules detected."
fi

if grep -q "Chain INPUT (policy ACCEPT" "$TMPDIR/iptables.txt"; then
    echo "[SECURITY] iptables INPUT default policy is ACCEPT."
fi

if grep -Eq '0\.0\.0\.0:|\[::\]:' "$TMPDIR/listening.txt"; then
    echo "[SECURITY] Services are listening on all network interfaces."
fi

if grep -Eq '(:3306|:5432|:1433|:1521|:27017|:6379)' \
"$TMPDIR/listening.txt"; then
    echo "[DATABASE] Common database listener detected."
fi

if grep -Eqi 'mysql|mariadb|postgres|mongodb|redis|oracle|mssql' \
"$TMPDIR/database-services.txt"; then
    echo "[DATABASE] Database service detected."
fi

if grep -qi "Docker version" "$TMPDIR/docker-version.txt"; then
    echo "[CONTAINER] Docker detected."
fi

if ! grep -qi "kubectl not detected" "$TMPDIR/kubernetes.txt"; then
    echo "[KUBERNETES] kubectl detected; Kubernetes investigation required."
fi

if [ -s "$TMPDIR/custom-services.txt" ]; then
    echo "[APPLICATION] Custom systemd service files detected:"
    sed 's/^/  - /' "$TMPDIR/custom-services.txt"
fi

if grep -q "loaded units listed" "$TMPDIR/failed.txt" &&
   ! grep -q "0 loaded units listed" "$TMPDIR/failed.txt"; then
    echo "[HEALTH] Failed systemd units detected; review required."
fi

if [ -f /var/run/reboot-required ]; then
    echo "[MAINTENANCE] Server currently requires a reboot."
fi

echo
echo "IMPORTANT:"
echo "Automated discovery finds infrastructure-level evidence."
echo "Application/database-specific dependencies must still be verified manually."
echo "Customer statements must be checked against discovered technical evidence."
echo

# ============================================================
# FULL TECHNICAL EVIDENCE
# ============================================================

section "HOST / OS" "$TMPDIR/hostname.txt"
section "KERNEL" "$TMPDIR/kernel.txt"
section "UPTIME" "$TMPDIR/uptime.txt"
section "LOCAL USERS" "$TMPDIR/users.txt"

section "CPU" "$TMPDIR/cpu.txt"
section "MEMORY / SWAP" "$TMPDIR/memory.txt"

section "DISKS" "$TMPDIR/disks.txt"
section "FILESYSTEM USAGE" "$TMPDIR/filesystem.txt"
section "INODE USAGE" "$TMPDIR/inode.txt"
section "BLOCK DEVICE IDENTIFIERS" "$TMPDIR/blkid.txt"

section "LVM PHYSICAL VOLUMES" "$TMPDIR/pvs.txt"
section "LVM VOLUME GROUPS" "$TMPDIR/vgs.txt"
section "LVM LOGICAL VOLUMES" "$TMPDIR/lvs.txt"

section "SOFTWARE RAID" "$TMPDIR/raid.txt"
section "MULTIPATH STORAGE" "$TMPDIR/multipath.txt"

section "NETWORK INTERFACES" "$TMPDIR/interfaces.txt"
section "IPv4 ROUTING" "$TMPDIR/routes.txt"
section "IPv6 ROUTING" "$TMPDIR/ipv6-routes.txt"
section "ARP / NEIGHBOURS" "$TMPDIR/neighbours.txt"
section "DNS CONFIGURATION" "$TMPDIR/dns.txt"
section "NETWORKMANAGER" "$TMPDIR/networkmanager.txt"

section "LISTENING PORTS" "$TMPDIR/listening.txt"
section "NETWORK CONNECTIONS" "$TMPDIR/connections.txt"

section "MOUNTED FILESYSTEMS" "$TMPDIR/mounts.txt"
section "REMOTE FILESYSTEMS" "$TMPDIR/remote-mounts.txt"
section "PERSISTENT MOUNTS" "$TMPDIR/fstab.txt"
section "NFS EXPORT CONFIGURATION" "$TMPDIR/exports.txt"
section "ACTIVE NFS EXPORTS" "$TMPDIR/nfs-exports.txt"
section "SAMBA STATUS" "$TMPDIR/samba-status.txt"
section "SAMBA SHARE NAMES" "$TMPDIR/samba-shares.txt"
section "ISCSI" "$TMPDIR/iscsi.txt"

section "RUNNING SERVICES" "$TMPDIR/services-running.txt"
section "ENABLED SERVICES" "$TMPDIR/services-enabled.txt"
section "FAILED SERVICES" "$TMPDIR/failed-services.txt"
section "CUSTOM SYSTEMD SERVICES" "$TMPDIR/custom-services.txt"

section "SYSTEMD TIMERS" "$TMPDIR/timers.txt"
section "USER CRON" "$TMPDIR/user-cron.txt"
section "ROOT CRON" "$TMPDIR/root-cron.txt"
section "SYSTEM CRON DIRECTORIES" "$TMPDIR/cron-files.txt"

section "UFW" "$TMPDIR/ufw.txt"
section "NFTABLES" "$TMPDIR/nftables.txt"
section "IPTABLES" "$TMPDIR/iptables.txt"
section "IP6TABLES" "$TMPDIR/ip6tables.txt"
section "FIREWALLD" "$TMPDIR/firewalld.txt"
section "APPARMOR" "$TMPDIR/apparmor.txt"
section "SELINUX" "$TMPDIR/selinux.txt"
section "SSH SECURITY SETTINGS" "$TMPDIR/ssh-security.txt"

section "NGINX VERSION" "$TMPDIR/nginx-version.txt"
section "NGINX CONFIGURATION FILES" "$TMPDIR/nginx-sites.txt"
section "NGINX SAFE ROUTING DIRECTIVES" "$TMPDIR/nginx-routing.txt"

section "APACHE VERSION" "$TMPDIR/apache-version.txt"
section "APACHE SITES" "$TMPDIR/apache-sites.txt"
section "APACHE MODULES" "$TMPDIR/apache-modules.txt"

section "DATABASE SOFTWARE" "$TMPDIR/database-software.txt"
section "DATABASE SERVICES" "$TMPDIR/database-services.txt"

section "DOCKER VERSION" "$TMPDIR/docker-version.txt"
section "DOCKER CONTAINERS" "$TMPDIR/docker-containers.txt"
section "DOCKER IMAGES" "$TMPDIR/docker-images.txt"
section "DOCKER NETWORKS" "$TMPDIR/docker-networks.txt"
section "DOCKER VOLUMES" "$TMPDIR/docker-volumes.txt"
section "CONTAINERD" "$TMPDIR/containerd.txt"
section "KUBERNETES CLIENT" "$TMPDIR/kubernetes.txt"

section "APPLICATION RUNTIMES" "$TMPDIR/runtimes.txt"
section "RELEVANT PACKAGES" "$TMPDIR/packages.txt"
section "POSSIBLE APPLICATION DIRECTORIES" "$TMPDIR/app-dirs.txt"
section "ENVIRONMENT FILE METADATA ONLY" "$TMPDIR/env-files.txt"

section "CERTIFICATE METADATA" "$TMPDIR/certificates.txt"

section "FAILED SYSTEMD UNITS" "$TMPDIR/failed.txt"
section "RECENT KERNEL/SYSTEM ERRORS" "$TMPDIR/kernel-errors.txt"
section "REBOOT REQUIREMENT" "$TMPDIR/reboot-required.txt"

echo
echo "============================================================"
echo " DISCOVERY COMPLETE"
echo "============================================================"
