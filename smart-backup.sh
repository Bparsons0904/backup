#!/bin/bash

# Smart backup script for XPS17 laptop
# Checks conditions before running borgmatic backup

set -euo pipefail

# Configuration
CONFIG_FILE="/home/bobparsons/Development/backup/config-xps17.yaml"
BORGMATIC_PATH="/home/bobparsons/.local/bin/borgmatic"
LOG_FILE="/var/log/smart-backup.log"
METRICS_FILE="/home/bobparsons/Development/backup/metrics/borgmatic_xps17.prom"
BACKUP_REPO="/mnt/nas/backups/xps17"

# Thresholds
MIN_BATTERY_PERCENT=30
BACKUP_INTERVAL_HOURS=3
BACKUP_TIMEOUT_MINUTES=60

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    log "ERROR: This script must be run as root (for system file access)"
    exit 1
fi

log "Starting smart backup check..."

# 1. Check if NAS is mounted and accessible
check_nas() {
    log "Checking NAS connectivity..."
    
    if ! mountpoint -q /mnt/nas; then
        log "ERROR: NAS not mounted at /mnt/nas"
        return 1
    fi
    
    if ! timeout 10 ls "$BACKUP_REPO" >/dev/null 2>&1; then
        log "ERROR: Cannot access backup repository at $BACKUP_REPO"
        return 1
    fi
    
    log "✓ NAS is accessible"
    return 0
}

# 2. Check battery level (if on laptop)
check_battery() {
    log "Checking battery level..."
    
    # Check if we have battery info
    if ! ls /sys/class/power_supply/BAT* >/dev/null 2>&1; then
        log "INFO: No battery detected (desktop system?)"
        return 0
    fi
    
    # Get battery percentage
    local battery_percent
    for battery in /sys/class/power_supply/BAT*; do
        if [[ -f "$battery/capacity" ]]; then
            battery_percent=$(cat "$battery/capacity")
            break
        fi
    done
    
    if [[ -z "${battery_percent:-}" ]]; then
        log "WARNING: Could not read battery level"
        return 0
    fi
    
    # Check if plugged in
    local ac_online=false
    for ac in /sys/class/power_supply/A{C,DP}*; do
        if [[ -f "$ac/online" ]] && [[ $(cat "$ac/online") == "1" ]]; then
            ac_online=true
            break
        fi
    done
    
    log "Battery: ${battery_percent}%, AC: $([ "$ac_online" = true ] && echo "connected" || echo "disconnected")"
    
    # Allow backup if AC connected OR battery > threshold
    if [[ "$ac_online" = true ]] || [[ "$battery_percent" -gt "$MIN_BATTERY_PERCENT" ]]; then
        log "✓ Battery level acceptable for backup"
        return 0
    else
        log "ERROR: Battery too low ($battery_percent% < $MIN_BATTERY_PERCENT%) and not plugged in"
        return 1
    fi
}

# 3. Check last backup time
check_last_backup() {
    log "Checking last backup time..."
    
    # Get timestamp of most recent archive
    local last_backup_time
    if ! last_backup_time=$(echo "y" | borg list --short "$BACKUP_REPO" 2>/dev/null | tail -1 | grep -o '[0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}T[0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}' || true); then
        log "WARNING: Could not get last backup time, assuming backup needed"
        return 0
    fi
    
    if [[ -z "$last_backup_time" ]]; then
        log "INFO: No previous backups found"
        return 0
    fi
    
    # Convert to epoch time
    local last_backup_epoch
    last_backup_epoch=$(date -d "$last_backup_time" +%s)
    local current_epoch
    current_epoch=$(date +%s)
    local hours_since_backup
    hours_since_backup=$(( (current_epoch - last_backup_epoch) / 3600 ))
    
    log "Last backup: $last_backup_time (${hours_since_backup} hours ago)"
    
    if [[ "$hours_since_backup" -ge "$BACKUP_INTERVAL_HOURS" ]]; then
        log "✓ Backup needed (>$BACKUP_INTERVAL_HOURS hours since last backup)"
        return 0
    else
        log "INFO: Recent backup exists, skipping"
        return 1
    fi
}

# 4. Check system load
check_system_load() {
    log "Checking system load..."
    
    local load_1min
    load_1min=$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | tr -d ',')
    local cpu_count
    cpu_count=$(nproc)
    local load_threshold
    load_threshold=$(echo "$cpu_count * 0.8" | bc -l)
    
    log "Load: $load_1min, CPUs: $cpu_count, Threshold: $load_threshold"
    
    if (( $(echo "$load_1min < $load_threshold" | bc -l) )); then
        log "✓ System load acceptable"
        return 0
    else
        log "ERROR: System load too high ($load_1min >= $load_threshold)"
        return 1
    fi
}

# Run backup
run_backup() {
    log "Starting borgmatic backup..."
    
    # Run backup with timeout
    if timeout "${BACKUP_TIMEOUT_MINUTES}m" "$BORGMATIC_PATH" --config "$CONFIG_FILE"; then
        log "✓ Backup completed successfully"
        
        # Update metrics
        {
            echo "borgmatic_backup_success{config=\"xps17\"} 1"
            echo "borgmatic_backup_last_run_timestamp $(date +%s)"
        } > "$METRICS_FILE"
        
        return 0
    else
        local exit_code=$?
        log "ERROR: Backup failed with exit code $exit_code"
        
        # Update metrics
        {
            echo "borgmatic_backup_success{config=\"xps17\"} 0"
            echo "borgmatic_backup_last_run_timestamp $(date +%s)"
        } > "$METRICS_FILE"
        
        return $exit_code
    fi
}

# Main execution
main() {
    # Run all checks
    if ! check_nas; then
        log "Skipping backup: NAS check failed"
        exit 1
    fi
    
    if ! check_battery; then
        log "Skipping backup: Battery check failed"
        exit 1
    fi
    
    if ! check_last_backup; then
        log "Skipping backup: Recent backup exists"
        exit 0
    fi
    
    if ! check_system_load; then
        log "Skipping backup: System load too high"
        exit 1
    fi
    
    # All checks passed, run backup
    log "All checks passed, proceeding with backup"
    run_backup
}

# Ensure log directory exists
mkdir -p "$(dirname "$LOG_FILE")"
mkdir -p "$(dirname "$METRICS_FILE")"

# Run main function
main "$@"