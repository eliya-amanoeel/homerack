#!/usr/bin/env bash
# Baseline hardening for kish. Idempotent — safe to run more than once.
#
#   ssh -t pi@kish.lan 'sudo bash -s' < scripts/harden-kish.sh
#
# Installs the three things a Debian server on the internet is normally expected
# to have and this Pi did not:
#   1. unattended-upgrades — security patches apply themselves
#   2. fail2ban            — bans repeated auth failures
#   3. log2ram             — keeps /var/log in RAM, sparing the SD card
set -uo pipefail
[ "$(id -u)" -eq 0 ] || { echo "run me with sudo"; exit 1; }
say() { printf '\n\033[1m== %s\033[0m\n' "$1"; }

say "1/3  unattended-upgrades"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq unattended-upgrades apt-listchanges >/dev/null

cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF

# Security updates only, and never reboot on its own: this box is the LAN's
# only DNS server and the VPN endpoint. An unattended 2am reboot would take the
# household's internet with it. Reboots stay a decision, not a surprise.
cat > /etc/apt/apt.conf.d/52homelab-unattended <<'EOF'
Unattended-Upgrade::Origins-Pattern {
        "origin=Debian,codename=${distro_codename}-security,label=Debian-Security";
        "origin=Raspberry Pi Foundation,codename=${distro_codename},label=Raspberry Pi Foundation";
};
Unattended-Upgrade::Automatic-Reboot "false";
Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
Unattended-Upgrade::Remove-Unused-Dependencies "true";
EOF
systemctl enable --now unattended-upgrades >/dev/null 2>&1
echo "  configured: security origins only, no automatic reboot"

say "2/3  fail2ban"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq fail2ban >/dev/null

# nftables backend: this kernel has NO legacy iptables modules at all, so the
# default iptables banaction would fail silently — the same trap that broke
# wg-easy. systemd backend because Debian logs sshd to the journal, not
# /var/log/auth.log.
cat > /etc/fail2ban/jail.local <<'EOF'
[DEFAULT]
backend   = systemd
banaction = nftables-multiport
bantime   = 1h
findtime  = 10m
maxretry  = 5
# Never lock yourself out of the LAN or the VPN.
ignoreip  = 127.0.0.1/8 ::1 192.168.68.0/22 10.8.0.0/24

[sshd]
enabled = true
EOF
systemctl enable fail2ban >/dev/null 2>&1
systemctl restart fail2ban
echo "  configured: sshd jail, nftables backend, LAN and VPN exempt"

say "3/3  log2ram"
DEBIAN_FRONTEND=noninteractive apt-get install -y -qq log2ram >/dev/null
# /var/log is ~57M today; 192M leaves room without pressuring 3.7G of RAM.
sed -i 's/^SIZE=.*/SIZE=192M/' /etc/log2ram.conf 2>/dev/null
systemctl enable log2ram >/dev/null 2>&1
echo "  configured: SIZE=192M — takes effect after a reboot"

say "state"
systemctl is-enabled unattended-upgrades 2>/dev/null | sed 's/^/  unattended-upgrades: /'
systemctl is-active  fail2ban            2>/dev/null | sed 's/^/  fail2ban:            /'
systemctl is-enabled log2ram             2>/dev/null | sed 's/^/  log2ram:             /'
fail2ban-client status sshd 2>/dev/null | grep -E "Currently banned|Total banned" | sed 's/^/  /'

printf '\n\033[1mlog2ram needs a reboot to take effect.\033[0m\n'
printf 'Rebooting drops DNS and the VPN for ~40s. Do it when convenient:\n'
printf '  ssh -t pi@kish.lan sudo reboot\n'
