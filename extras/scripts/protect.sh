#!/usr/bin/env bash
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
#   @note           Bash version using associative arrays and mapfile.
#                   Includes --show-config option for viewing script settings.
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
#                   - Supports multi-vhost access logs under /home/<user>/access-logs/
# #

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

THRESHOLD_DEFAULT=500
LOG_DATE="$(date +%d/%b/%Y)"
CSF_DENY_FILE="/etc/csf/csf.deny"
ACTION_LOG="/var/log/protect.log"

# Format: label|/path/to/logfile|reason
SITES=(
  "site1|/home/site1/access-logs/site1.com-ssl_log|site1 abuse"
  "site2|/home/site2/access-logs/site2.com-ssl_log|site2 abuse"
  "site3|/home/site3/access-logs/site3.com-ssl_log|site3 abuse"
  "site4|/home/site4/access-logs/site4.com-ssl_log|site4 abuse"
)

# Private/reserved IP prefixes
PRIVATE_PREFIXES_IPV4=(
  "10." "192.168." "127." "169.254."
  "172.16." "172.17." "172.18." "172.19."
  "172.20." "172.21." "172.22." "172.23."
  "172.24." "172.25." "172.26." "172.27."
  "172.28." "172.29." "172.30." "172.31."
)
PRIVATE_PREFIXES_IPV6=("::1" "fe80:" "fc00:" "fd")

# -----------------------------------------------------------------------------
# Helper functions
# -----------------------------------------------------------------------------

log() {
  local msg="$1"
  printf '%s %s\n' "$(date '+%Y-%m-%d %H:%M:%S')" "$msg" | tee -a "$ACTION_LOG"
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
  for p in "${PRIVATE_PREFIXES_IPV4[@]}"; do
    echo "    - $p"
  done
  echo "  Private IPv6 ranges skipped:"
  for p in "${PRIVATE_PREFIXES_IPV6[@]}"; do
    echo "    - $p"
  done
  echo "  Sites monitored:"
  for def in "${SITES[@]}"; do
    IFS='|' read -r label log_path reason <<< "$def"
    echo "    - $label ($log_path) reason=\"$reason\""
  done
  echo
  echo "Run with --dry-run to simulate blocking or --threshold N to change the hit limit."
}

is_private_ip() {
  local ip="$1"
  if [[ "$ip" == *:* ]]; then
    for p in "${PRIVATE_PREFIXES_IPV6[@]}"; do [[ "$ip" == "$p"* ]] && return 0; done
  else
    for p in "${PRIVATE_PREFIXES_IPV4[@]}"; do [[ "$ip" == "$p"* ]] && return 0; done
  fi
  return 1
}

in_csf_deny() {
  local ip="$1"
  [[ -f "$CSF_DENY_FILE" ]] || return 1
  grep -Fq -- "$ip" "$CSF_DENY_FILE"
}

# -----------------------------------------------------------------------------
# Argument parsing
# -----------------------------------------------------------------------------

THRESHOLD="$THRESHOLD_DEFAULT"
DRY_RUN=0
SHOW_CONFIG=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --threshold) THRESHOLD="$2"; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    --show-config) SHOW_CONFIG=1; shift ;;
    --help|-h) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

if (( SHOW_CONFIG == 1 )); then
  show_config
  exit 0
fi

if (( DRY_RUN == 1 )); then
  log "Starting protect.sh (DRY RUN) — threshold ${THRESHOLD} for date ${LOG_DATE}"
else
  log "Starting protect.sh — threshold ${THRESHOLD} for date ${LOG_DATE}"
fi

# -----------------------------------------------------------------------------
# Preconditions
# -----------------------------------------------------------------------------

if (( DRY_RUN == 0 )); then
  if [[ $EUID -ne 0 ]]; then
    log "ERROR: script must be run as root to block. Exiting."
    exit 1
  fi
  if ! command -v csf >/dev/null 2>&1; then
    log "ERROR: csf binary not found. Install CSF and try again."
    exit 1
  fi
fi

# -----------------------------------------------------------------------------
# Collect offenders
# -----------------------------------------------------------------------------

declare -A OFFENDERS_COUNT
declare -A OFFENDERS_REASON

for def in "${SITES[@]}"; do
  IFS='|' read -r label log_path reason <<< "$def"
  if [[ ! -f "$log_path" ]]; then
    log "[$label] log not found: $log_path — skipping"
    continue
  fi

  mapfile -t lines < <(awk -v d="$LOG_DATE" '$0 ~ d {print $1}' "$log_path" | sort | uniq -c | awk '{print $1 " " $2}')

  if [[ ${#lines[@]} -eq 0 ]]; then
    log "[$label] no hits today."
    continue
  fi

  for ln in "${lines[@]}"; do
    cnt="${ln%% *}"
    ip="${ln##* }"
    [[ "$cnt" =~ ^[0-9]+$ ]] || continue
    if (( cnt > THRESHOLD )); then
      prev="${OFFENDERS_COUNT[$ip]:-0}"
      if (( cnt > prev )); then
        OFFENDERS_COUNT["$ip"]="$cnt"
      fi
      OFFENDERS_REASON["$ip"]="${OFFENDERS_REASON[$ip]:-}${label}:${reason};"
    fi
  done
done

if ((${#OFFENDERS_COUNT[@]} == 0)); then
  log "No offenders above threshold ($THRESHOLD). Exiting."
  exit 0
fi

# -----------------------------------------------------------------------------
# Summary report
# -----------------------------------------------------------------------------

log "Found ${#OFFENDERS_COUNT[@]} offender(s) above threshold:"
printf "%-39s  %8s  %s\n" "IP" "HITS" "SITES/REASONS" | tee -a "$ACTION_LOG"

for ip in "${!OFFENDERS_COUNT[@]}"; do
  printf "%-39s  %8s  %s\n" "$ip" "${OFFENDERS_COUNT[$ip]}" "${OFFENDERS_REASON[$ip]}" | tee -a "$ACTION_LOG"
done

# -----------------------------------------------------------------------------
# Enforce blocks
# -----------------------------------------------------------------------------

CHANGES=0

for ip in "${!OFFENDERS_COUNT[@]}"; do
  if is_private_ip "$ip"; then
    log "SKIP ${ip} — private/reserved"
    continue
  fi

  if in_csf_deny "$ip"; then
    log "ALREADY DENIED ${ip} — skipping"
    continue
  fi

  block_reason="auto-block hits>${THRESHOLD} ${OFFENDERS_REASON[$ip]}"

  if (( DRY_RUN == 1 )); then
    log "DRY: would run: csf -d ${ip} \"${block_reason}\""
    CHANGES=$((CHANGES + 1))
  else
    log "Blocking ${ip} — reason: ${block_reason}"
    if csf -d "$ip" "$block_reason"; then
      CHANGES=$((CHANGES + 1))
      log "Blocked ${ip} successfully."
    else
      log "ERROR: failed to block ${ip} with csf -d"
    fi
  fi
done

if (( CHANGES > 0 )); then
  if (( DRY_RUN == 1 )); then
    log "DRY-RUN: ${CHANGES} would be changed. No csf -r executed."
  else
    log "Reloading CSF to apply ${CHANGES} new deny(s)..."
    csf -r && log "CSF reload completed."
  fi
else
  log "No new denies were required."
fi

log "protect.sh finished."
exit 0
