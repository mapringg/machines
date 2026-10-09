#!/usr/bin/env bash
set -euo pipefail

[ "$EUID" -eq 0 ] || exec sudo "$0" "$@"
HOURS=${1:-24}
HOME_DIR=$(getent passwd "${SUDO_USER:-root}" | cut -d: -f6)
STAMP=$(date +%F-%H%M)
LOG=$HOME_DIR/burnin-$STAMP.log
TEMPS=$HOME_DIR/burnin-$STAMP-temps.csv
exec > >(tee "$LOG") 2>&1
fail=0

apt install -y stress-ng fio smartmontools memtest86+

echo "== inventory"
lscpu | grep -E '^(Model name|CPU\(s\)):'
free -h
dmidecode -t memory | grep -E '^\s+(Locator|Size|Type|Speed|Configured Memory Speed|Part Number):' || true
DISK=/dev/$(lsblk -dno NAME,TYPE | awk '$2 == "disk" && $1 ~ /^nvme/ {print $1; exit}')
smartctl -i "$DISK" || true

echo "== SSD write and verify"
FIO=$HOME_DIR/burnin-fio.tmp
fio --name=write-verify --filename="$FIO" --size=20G --rw=write --bs=1M \
  --direct=1 --ioengine=libaio --iodepth=16 --verify=crc32c || fail=1
fio --name=randread --filename="$FIO" --size=20G --rw=randread --bs=4k \
  --direct=1 --ioengine=libaio --iodepth=64 --runtime=60 --time_based || fail=1
rm -f "$FIO"

echo "== SSD self-test"
smartctl -t long "$DISK" || echo "Self-test not supported; skipping"

hwmon() {
  for d in /sys/class/hwmon/hwmon*; do
    [ "$(cat "$d/name")" = "$1" ] && { echo "$d/temp1_input"; return; }
  done
  return 0
}
celsius() { [ -n "$1" ] && echo $(( $(cat "$1") / 1000 )) || echo NA; }
CPU_T=$(hwmon k10temp)
NVME_T=$(hwmon nvme)
echo "time,cpu_c,nvme_c,avg_mhz" >"$TEMPS"
while :; do
  printf '%s,%s,%s,%s\n' "$(date +%T)" "$(celsius "$CPU_T")" "$(celsius "$NVME_T")" \
    "$(awk '/^cpu MHz/ {s += $4; n++} END {printf "%d", s / n}' /proc/cpuinfo)"
  sleep 30
done >>"$TEMPS" &
logger=$!
trap 'kill $logger 2>/dev/null' EXIT

echo "== stress for ${HOURS}h, started $(date +%T)"
stress-ng --cpu 0 --vm 2 --vm-bytes 75% --verify --metrics-brief \
  --timeout "${HOURS}h" || fail=1
kill $logger

echo "== SSD health"
if smartctl -H "$DISK" | grep -q PASSED; then
  echo "health: PASSED"
else
  echo "health: FAILED"
  fail=1
fi
smartctl -A -l selftest "$DISK" || true

echo "== kernel hardware errors"
if journalctl -k -b --no-pager | grep -iE 'machine check|hardware error|nvme.*(timeout|reset)|I/O error'; then
  fail=1
else
  echo "none"
fi

echo "== temperatures under stress"
awk -F, 'NR > 3 && $2 != "NA" {
  if ($2 > cpu) cpu = $2; if ($3 > nvme) nvme = $3
  if (!mhz || $4 < mhz) mhz = $4 }
  END { printf "max CPU %s C, max SSD %s C, lowest avg clock %s MHz\n", cpu, nvme, mhz }' "$TEMPS"

echo
(( fail )) && echo "RESULT: FAIL, return it" || echo "RESULT: PASS"
echo "Log: $LOG"
exit $fail
