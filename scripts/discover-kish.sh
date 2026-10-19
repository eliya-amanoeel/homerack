#!/usr/bin/env bash
# Discovery: dump everything about kish needed to fill in the docs.
# Read-only — changes nothing. Run it ON the Pi, or via:
#
#   ssh pi@kish.lan 'bash -s' < scripts/discover-kish.sh > /tmp/kish-discovery.txt
#
# Use the output to fill in docs/inventory.md, docs/network.md and the stack
# compose files, then delete it. Never commit it: it holds secrets, and
# .gitignore covers *-discovery.txt (ADR 0003).

set -uo pipefail
sec() { printf '\n\n===== %s =====\n' "$1"; }

sec "HOST / OS  (-> inventory.md: OS version, architecture)"
hostname
uname -a
echo "arch: $(uname -m)   # aarch64: image tags need linux/arm64 variants"
cat /etc/os-release 2>/dev/null | grep -E 'PRETTY_NAME|VERSION_CODENAME'
getconf LONG_BIT | sed 's/^/userland bits: /'
uptime

sec "HARDWARE  (-> inventory.md: RAM, model)"
cat /proc/device-tree/model 2>/dev/null; echo
free -h
vcgencmd get_throttled 2>/dev/null | sed 's/$/   # 0x0 = healthy power/'

sec "STORAGE  (-> inventory.md, HL-03 SD card check)"
lsblk -o NAME,SIZE,TYPE,TRAN,MODEL,MOUNTPOINT
echo "--- root filesystem ---"
findmnt -no SOURCE,FSTYPE,SIZE,USED /
echo "# mmcblk* = SD card (HL-03 applies).  sd*/nvme* with TRAN=usb = SSD, good."
df -h / /boot 2>/dev/null

sec "NETWORK  (-> network.md: IPs and MACs)"
ip -br addr
echo "--- default route / gateway ---"
ip route | grep default
echo "--- MACs ---"
ip -br link | awk '{print $1, $3}'
echo "--- is the IP static? ---"
grep -rsE 'static|address' /etc/dhcpcd.conf /etc/network/interfaces \
  /etc/netplan/*.yaml 2>/dev/null | grep -v '^\s*#' | head -20
nmcli -t -f NAME,DEVICE,TYPE con show 2>/dev/null

sec "DNS  (-> network.md: upstream resolvers)"
cat /etc/resolv.conf 2>/dev/null | grep -v '^#'
systemctl is-active systemd-resolved 2>/dev/null | sed 's/^/systemd-resolved: /'
ss -tulpn 2>/dev/null | grep -E ':53\b' || echo "(need sudo to see :53 owner)"

sec "DOCKER CONTAINERS  (-> HL-06 reconcile, HL-17 portainer)"
docker ps -a --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}'

sec "DOCKER: restart policies + mounts per container  (-> HL-06)"
for c in $(docker ps -a --format '{{.Names}}'); do
  echo "--- $c ---"
  docker inspect "$c" --format \
    'image:   {{.Config.Image}}
restart: {{.HostConfig.RestartPolicy.Name}}
mounts:  {{range .Mounts}}{{.Source}} -> {{.Destination}} ({{.Type}})
         {{end}}ports:   {{range $p, $b := .NetworkSettings.Ports}}{{$p}} -> {{range $b}}{{.HostPort}}{{end}} {{end}}'
done

sec "DOCKER: environment variables  (-> HL-06; REDACT SECRETS BEFORE COMMITTING)"
echo "!! Passwords appear below. Replace with placeholders before pasting anywhere."
for c in $(docker ps -a --format '{{.Names}}'); do
  echo "--- $c ---"
  docker inspect "$c" --format '{{range .Config.Env}}{{println .}}{{end}}' \
    | grep -vE '^(PATH|HOME|LANG|TERM|GPG_KEY|PYTHON|NODE_VERSION|S6_|container=)'
done

sec "DOCKER: existing compose files on disk  (-> HL-06, the real source)"
find / -name 'docker-compose*.y*ml' -not -path '*/data/*' 2>/dev/null | head -20

sec "COMPOSE PROJECTS / STACKS"
docker compose ls 2>/dev/null || echo "(compose v2 plugin not present)"
docker volume ls

sec "PORTS IN USE  (-> network.md service table, ADR 0002 / HL-22)"
ss -tulpn 2>/dev/null | grep LISTEN | sort -t: -k2 -n || netstat -tulpn 2>/dev/null

sec "PI-HOLE local DNS records  (-> network.md, Local DNS records)"
# Pi-hole v6 keeps them in dns.hosts in pihole.toml; custom.list is generated.
docker exec pihole pihole-FTL --config dns.hosts 2>/dev/null \
  || echo "(container not named 'pihole', or not Pi-hole v6)"

sec "SCHEDULED JOBS  (existing automation worth documenting)"
crontab -l 2>/dev/null || echo "(no user crontab)"
systemctl list-timers --no-pager 2>/dev/null | head -15

printf '\n\n===== END =====\nRemember: redact passwords before committing this.\n'
