#!/usr/bin/env bash
#
# support-check.sh — first-line diagnostics for a Linux workstation.
#
# A support-engineer triage script: it REPORTS only, it changes nothing.
# Collects system info, resource usage, top processes, network connectivity
# (gateway, DNS server, name resolution), service status and recent errors,
# then saves a timestamped plain-text report that can be attached to a
# ticket or handed to L2.
#
# Usage:
#   ./support-check.sh              # print summary + save report
#   ./support-check.sh --report-only
#
# The report is written to reports/support-check-<hostname>-<timestamp>.txt
# Companion to the Windows script in ../windows/Support-Check.ps1.
#
set -u

# ---------- config ----------
WARN_CPU=70        # %  -> warning above this
CRIT_CPU=90        # %  -> critical above this
WARN_MEM=75
CRIT_MEM=90
WARN_DISK=75
CRIT_DISK=90
SERVICES=("ssh" "cron" "NetworkManager")   # services expected to be running
REPORT_DIR="$(cd "$(dirname "$0")" && pwd)/reports"
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
HOST="$(hostname)"
REPORT="$REPORT_DIR/support-check-$HOST-$TIMESTAMP.txt"

# ---------- helpers ----------
RED='\033[0;31m'; YELLOW='\033[0;33m'; GREEN='\033[0;32m'; NC='\033[0m'

status_of() { # status_of <value> <warn> <crit> -> OK|WARNING|CRITICAL
    local val=$1 warn=$2 crit=$3
    if awk "BEGIN{exit !($val >= $crit)}"; then echo "CRITICAL"
    elif awk "BEGIN{exit !($val >= $warn)}"; then echo "WARNING"
    else echo "OK"; fi
}

color_for() {
    case "$1" in
        CRITICAL) echo "$RED";; WARNING) echo "$YELLOW";; *) echo "$GREEN";;
    esac
}

line() { printf '%s\n' "$1" | tee -a "$REPORT"; }
section() { line ""; line "== $1 =="; }

mkdir -p "$REPORT_DIR"
: > "$REPORT"

# ---------- gather ----------
UPTIME="$(uptime -p 2>/dev/null || uptime)"
KERNEL="$(uname -r)"
DISTRO="$(grep '^PRETTY_NAME=' /etc/os-release 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "unknown")"

CPU_IDLE=$(awk '/^cpu /{printf "%.1f", $5*100/($2+$3+$4+$5+$6+$7+$8)}' /proc/stat 2>/dev/null || echo 0)
CPU_USED=$(awk "BEGIN{printf \"%.1f\", 100 - $CPU_IDLE}")

MEM_TOTAL_KB=$(awk '/MemTotal/{print $2}' /proc/meminfo)
MEM_AVAIL_KB=$(awk '/MemAvailable/{print $2}' /proc/meminfo)
MEM_USED=$(awk "BEGIN{printf \"%.1f\", 100 * (1 - $MEM_AVAIL_KB / $MEM_TOTAL_KB)}")
MEM_USED_MB=$(awk "BEGIN{printf \"%.0f\", ($MEM_TOTAL_KB - $MEM_AVAIL_KB) / 1024}")
MEM_TOTAL_MB=$(awk "BEGIN{printf \"%.0f\", $MEM_TOTAL_KB / 1024}")

DISK_USED=$(df -h / | awk 'NR==2{gsub(/%/,""); print $5}')
DISK_AVAIL=$(df -h / | awk 'NR==2{print $4}')

LOAD=$(cut -d' ' -f1-3 /proc/loadavg)

CPU_STATUS=$(status_of "$CPU_USED" "$WARN_CPU" "$CRIT_CPU")
MEM_STATUS=$(status_of "$MEM_USED" "$WARN_MEM" "$CRIT_MEM")
DISK_STATUS=$(status_of "$DISK_USED" "$WARN_DISK" "$CRIT_DISK")

# ---------- report ----------
line "Support Check — $HOST"
line "Generated: $(date '+%F %T %Z')"
line "OS: $DISTRO | Kernel: $KERNEL"
line "Uptime: $UPTIME | Load (1/5/15m): $LOAD"

section "RESOURCE SUMMARY"
line "CPU:    ${CPU_USED}%  [$CPU_STATUS]"
line "Memory: ${MEM_USED}% (${MEM_USED_MB}MB / ${MEM_TOTAL_MB}MB)  [$MEM_STATUS]"
line "Disk /: ${DISK_USED}% used, ${DISK_AVAIL} free  [$DISK_STATUS]"

section "TOP PROCESSES"
line "-- by CPU --"
ps -eo pcpu,pid,comm --sort=-pcpu 2>/dev/null | head -6 >> "$REPORT"
line "-- by memory --"
ps -eo pmem,pid,comm --sort=-pmem 2>/dev/null | head -6 >> "$REPORT"

section "NETWORK"
if command -v ip >/dev/null 2>&1; then
    line "-- interfaces --"
    ip -brief addr 2>/dev/null >> "$REPORT" || line "(could not list interfaces)"
    GATEWAY=$(ip route 2>/dev/null | awk '/^default/{print $3; exit}')
else
    line "Addresses: $(hostname -I 2>/dev/null || echo unknown)"
    GATEWAY=""
fi
if [ -n "${GATEWAY:-}" ]; then
    if ping -c 2 -W 2 "$GATEWAY" >/dev/null 2>&1; then
        line "Gateway $GATEWAY: reachable"
    else
        line "Gateway $GATEWAY: NOT REACHABLE"
    fi
else
    line "Gateway: not found (no default route)"
fi
if ping -c 2 -W 2 8.8.8.8 >/dev/null 2>&1; then
    line "Internet (8.8.8.8): reachable"
else
    line "Internet (8.8.8.8): NOT REACHABLE"
fi
if command -v getent >/dev/null 2>&1; then
    if getent hosts example.com >/dev/null 2>&1; then
        line "DNS resolution (example.com): OK"
    else
        line "DNS resolution (example.com): FAILED"
    fi
else
    line "DNS resolution: getent not available — skipping"
fi

section "SERVICE STATUS"
for svc in "${SERVICES[@]}"; do
    if systemctl is-active --quiet "$svc" 2>/dev/null; then
        line "$svc: running"
    elif pgrep -x "$svc" >/dev/null 2>&1 || pgrep -f "$svc" >/dev/null 2>&1; then
        line "$svc: running (process found, no systemd)"
    else
        line "$svc: NOT RUNNING"
    fi
done

section "RECENT SYSTEM ERRORS (last 24h)"
if command -v journalctl >/dev/null 2>&1; then
    ERRORS=$(journalctl -p err --since "24 hours ago" --no-pager -n 10 2>/dev/null)
    if [ -n "$ERRORS" ]; then
        printf '%s\n' "$ERRORS" >> "$REPORT"
    else
        line "No errors in the last 24h (or journal not readable)."
    fi
else
    line "journalctl not available — skipping."
fi

section "FAILED SSH LOGINS (recent)"
if [ -r /var/log/auth.log ]; then
    FAILED=$(grep -c "Failed password" /var/log/auth.log 2>/dev/null || echo 0)
    line "Failed password attempts in current auth.log: $FAILED"
    grep "Failed password" /var/log/auth.log 2>/dev/null | tail -5 >> "$REPORT" || true
elif [ -r /var/log/secure ]; then
    FAILED=$(grep -c "Failed password" /var/log/secure 2>/dev/null || echo 0)
    line "Failed password attempts in /var/log/secure: $FAILED"
else
    line "Auth log not readable (needs root) — skipping."
fi

# ---------- console summary ----------
if [ "${1:-}" != "--report-only" ]; then
    echo ""
    echo "Support summary for $HOST:"
    printf "  CPU:    %b%s%% [%s]%b\n" "$(color_for "$CPU_STATUS")" "$CPU_USED" "$CPU_STATUS" "$NC"
    printf "  Memory: %b%s%% [%s]%b\n" "$(color_for "$MEM_STATUS")" "$MEM_USED" "$MEM_STATUS" "$NC"
    printf "  Disk /: %b%s%% [%s]%b\n" "$(color_for "$DISK_STATUS")" "$DISK_USED" "$DISK_STATUS" "$NC"
fi

echo ""
echo "Full report saved to: $REPORT"
