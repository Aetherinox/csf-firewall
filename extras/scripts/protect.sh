#!/bin/sh
# shellcheck shell=sh
# #
#   ConfigServer Firewall - protect.sh
#
#   @author         theking81
#   @package        ConfigServer Firewall
#   @file           protect.sh
#   @type           extras/helper
#   @license        MIT
#   @desc           Scans today's SSL access logs for abusive IPs and blocks them
#                   in CSF if they exceed a defined request threshold.
#
#   @note           POSIX /bin/sh version — portable for all systems.
#                   Includes --show-config option for viewing current settings.
# #
#
# #
#   @usage          sudo /usr/local/sbin/protect.sh
#                   sudo /usr/local/sbin/protect.sh --dry-run
#                   sudo /usr/local/sbin/protect.sh --threshold 300
#                   protect.sh --show-config
#
#   @notes          - Logs actions to /var/log/protect.log
#                   - Threshold defaults to 500 hits per IP (per day, per vhost log)
#                   - Skips private/reserved IPs
#                   - Checks csf.deny before adding duplicates
#                   - Compatible with multi-vhost access logs under /home/<user>/access-logs/
# #

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

THRESHOLD_DEFAULT=500
LOG_DATE="$(date +%d/%b/%Y)"
CSF_DENY_FILE="/etc/csf/csf.deny"
ACTION_LOG="/var/log/protect.log"

SITES="
site1|/home/site1/access-logs/site1.com-ssl_log|site1 abuse
site2|/home/site2/access-logs/site2.com-ssl_log|site2 abuse
site3|/home/site3/access-logs/site3.com-ssl_log|site3 abuse
site4|/home/site4/access-logs/site4.com-ssl_log|site4 abuse
"

PRIVATE_PREFIXES_IPV4="
10.
192.168.
127.
169.254.
172.16.
172.17.
172.18.
172.19.
172.20.
172.21.
172.22.
172.23.
172.24.
172.25.
172.26.
172.27.
172.28.
172.29.
172.30.
172.31.
"

PRIVATE_PREFIXES_IPV6="
::1
fe80:
fc00:
fd
"

OFFENDERS_TMP="$(mktemp /tmp/protect.offenders.XXXXXX)"
TMPFILE="$(mktemp /tmp/protect.tmp.XXXXXX)"

cleanup() { rm -f "$OFFENDERS_TMP" "$TMPFILE"; }
trap cleanup EXIT INT TERM

# -----------------------------------------------------------------------------
# Functions
# -----------------------------------------------------------------------------

log() {
    printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$1" | tee -a "$ACTION_LOG"
}

usage() {
    cat <<EOF
protect.sh — scan logs and auto-block heavy IPs via CSF

Options:
  --threshold N    Hits threshold to block (default ${THRESHOLD_DEFAULT})
  --dry-run        Do not run csf -d / csf -r. Just report actions.
  --show-config    Print current settings and exit.
  --help, -h       Show this help and exit.

Examples:
  sudo protect.sh
  sudo protect.sh --dry-run
  sudo protect.sh --threshold 300
  protect.sh --show-config
EOF
}

show_config() {
    echo "protect.sh configuration:"
    echo "  Threshold:          ${THRESHOLD_DEFAULT}"
    echo "  Scan date:          ${LOG_DATE}"
    echo "  Action log:         ${ACTION_LOG}"
    echo "  CSF deny file:      ${CSF_DENY_FILE}"
    echo "  Private IPv4 ranges skipped:"
    echo "$PRIVATE_PREFIXES_IPV4" | sed 's/^/    - /' | sed '/^    - *$/d'
    echo "  Private IPv6 ranges skipped:"
    echo "$PRIVATE_PREFIXES_IPV6" | sed 's/^/    - /' | sed '/^    - *$/d'
    echo "  Sites monitored:"
    echo "$SITES" | while IFS='|' read -r label log_path reason; do
        [ -n "$label" ] || continue
        echo "    - $label ($log_path) reason=\"$reason\""
    done
    echo
    echo "Run with --dry-run to simulate blocking or --threshold N to change the hit limit."
}

is_private_ip() {
    ip="$1"
    case "$ip" in
        *:*)
            echo "$PRIVATE_PREFIXES_IPV6" | while IFS= read -r p; do
                [ -n "$p" ] || continue
                case "$ip" in ${p}*) exit 0 ;; esac
            done
            exit 1
            ;;
        *)
            echo "$PRIVATE_PREFIXES_IPV4" | while IFS= read -r p; do
                [ -n "$p" ] || continue
                case "$ip" in ${p}*) exit 0 ;; esac
            done
            exit 1
            ;;
    esac
}

in_csf_deny() {
    ip="$1"
    [ -f "$CSF_DENY_FILE" ] && grep -Fq -- "$ip" "$CSF_DENY_FILE"
}

record_offender() {
    ip="$1"
    count="$2"
    reason="$3"
    if grep -Fq "^$ip " "$OFFENDERS_TMP"; then
        old_line="$(grep -F "^$ip " "$OFFENDERS_TMP" | head -n1)"
        old_count="$(echo "$old_line" | awk '{print $2}')"
        old_reasons="$(echo "$old_line" | cut -d' ' -f3-)"
        [ "$count" -gt "$old_count" ] && new_count="$count" || new_count="$old_count"
        case "$old_reasons" in *"$reason"*) new_reasons="$old_reasons" ;; *) new_reasons="$old_reasons$reason;" ;; esac
        grep -Fv "^$ip " "$OFFENDERS_TMP" > "$TMPFILE"
        echo "$ip $new_count $new_reasons" >> "$TMPFILE"
        mv "$TMPFILE" "$OFFENDERS_TMP"
    else
        echo "$ip $count ${reason};" >> "$OFFENDERS_TMP"
    fi
}

# -----------------------------------------------------------------------------
# Args
# -----------------------------------------------------------------------------

THRESHOLD="$THRESHOLD_DEFAULT"
DRY_RUN=0
SHOW_CONFIG=0

while [ "$#" -gt 0 ]; do
    case "$1" in
        --threshold) THRESHOLD="$2"; shift 2 ;;
        --dry-run) DRY_RUN=1; shift ;;
        --show-config) SHOW_CONFIG=1; shift ;;
        --help|-h) usage; exit 0 ;;
        *) echo "Unknown option: $1"; usage; exit 1 ;;
    esac
done

if [ "$SHOW_CONFIG" -eq 1 ]; then
    show_config
    exit 0
fi

if [ "$DRY_RUN" -eq 1 ]; then
    log "Starting protect.sh (DRY RUN) — threshold ${THRESHOLD} for date ${LOG_DATE}"
else
    log "Starting protect.sh — threshold ${THRESHOLD} for date ${LOG_DATE}"
fi

# -----------------------------------------------------------------------------
# Pre-checks
# -----------------------------------------------------------------------------

if [ "$DRY_RUN" -eq 0 ]; then
    if [ "$(id -u)" -ne 0 ]; then
        log "ERROR: script must be run as root to block."
        exit 1
    fi
    if ! command -v csf >/dev/null 2>&1; then
        log "ERROR: csf binary not found."
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Scan logs
# -----------------------------------------------------------------------------

echo "$SITES" | while IFS='|' read -r label log_path reason; do
    [ -n "$label" ] || continue
    if [ ! -f "$log_path" ]; then
        log "[$label] log not found: $log_path — skipping"
        continue
    fi

    awk -v d="$LOG_DATE" '$0 ~ d {print $1}' "$log_path" \
        | sort | uniq -c | awk '{print $1 " " $2}' > "$TMPFILE"

    if [ ! -s "$TMPFILE" ]; then
        log "[$label] no hits today."
        continue
    fi

    while IFS=' ' read -r cnt ip; do
        case "$cnt" in ''|*[!0-9]*) continue ;; esac
        [ "$cnt" -gt "$THRESHOLD" ] && record_offender "$ip" "$cnt" "$label:$reason"
    done < "$TMPFILE"
done

if [ ! -s "$OFFENDERS_TMP" ]; then
    log "No offenders above threshold ($THRESHOLD)."
    exit 0
fi

# -----------------------------------------------------------------------------
# Report
# -----------------------------------------------------------------------------

log "Found offender(s) above threshold:"
printf "%-39s  %8s  %s\n" "IP" "HITS" "SITES/REASONS" | tee -a "$ACTION_LOG"
cat "$OFFENDERS_TMP" | while IFS=' ' read -r ip hits reasons; do
    printf "%-39s  %8s  %s\n" "$ip" "$hits" "$reasons" | tee -a "$ACTION_LOG"
done

# -----------------------------------------------------------------------------
# Block offenders
# -----------------------------------------------------------------------------

CHANGES=0

cat "$OFFENDERS_TMP" | while IFS=' ' read -r ip hits reasons; do
    if is_private_ip "$ip"; then log "SKIP $ip — private/reserved"; continue; fi
    if in_csf_deny "$ip"; then log "ALREADY DENIED $ip — skipping"; continue; fi

    block_reason="auto-block hits>${THRESHOLD} ${reasons}"
    if [ "$DRY_RUN" -eq 1 ]; then
        log "DRY: would run: csf -d $ip \"$block_reason\""
        CHANGES=$((CHANGES + 1))
    else
        log "Blocking $ip — reason: $block_reason"
        if csf -d "$ip" "$block_reason"; then
            CHANGES=$((CHANGES + 1))
            log "Blocked $ip successfully."
        else
            log "ERROR: failed to block $ip."
        fi
    fi
done

if [ "$CHANGES" -gt 0 ]; then
    if [ "$DRY_RUN" -eq 1 ]; then
        log "DRY-RUN: $CHANGES would be changed. No csf -r executed."
    else
        log "Reloading CSF to apply $CHANGES new deny(s)..."
        csf -r && log "CSF reload completed."
    fi
else
    log "No new denies were required."
fi

log "protect.sh finished."
exit 0
