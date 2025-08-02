# Borgmatic Backup Setup

## Project Overview
Setting up borgmatic for automated backups across multiple computers.

## Computers Configured
### Server
- **Config**: `config.yaml` 
- **Repository**: `/mnt/nas-direct/backups/server` (unencrypted)
- **Features**: ZFS integration, database backups
- **Status**: ✅ Complete

### XPS17
- **Config**: `config-xps17.yaml`
- **Repository**: `/mnt/nas/backups/xps17` (unencrypted)
- **Type**: Filesystem backup only with intelligent scheduling
- **Scheduling**: Smart backup script with conditions checking
- **Status**: ✅ Complete

### Mira
- **Config**: `config-mira.yaml`
- **Repository**: `/mnt/nas/backups/mira` (unencrypted)
- **Type**: Filesystem backup only (desktop system)
- **Status**: ✅ Complete

## Common Configuration
- **Retention**: 7 daily, 4 weekly, 12 monthly, 1 yearly
- **Installation**: borgmatic via pipx (version 2.0.7)
- **Scheduling**: Cron jobs (daily backups)

## Source Directories
### Server
- `/home` - User data
- `/etc` - System configuration  
- `/var/log` - System logs
- `/var/lib` - Application data and databases
- `/opt` - Third-party software

### Desktop Systems (XPS17, Mira)
- `/home` - User data
- `/etc` - System configuration
- `/var/log` - System logs  
- `/opt` - Third-party software

## Exclusion Patterns
### Common Exclusions
- Cache directories (`/home/*/.cache`, `/var/cache`)
- Temporary files (`/var/tmp`, `*.tmp`)
- Development artifacts (`node_modules`, `__pycache__`, `.git/objects`)
- Package manager caches (`.npm`, `.yarn/cache`)
- System journals and log rotations

### Desktop-Specific Exclusions
- Gaming: Steam directories (`/home/*/.local/share/Steam`)
- Downloads: ISO files, temp directories (`*.iso`, `*.img`, `/Downloads/temp`)
- Development: Python bytecode (`*.pyc`, `*.pyo`), Rust targets (`target/debug`, `target/release`)
- IDEs: VS Code extensions (`.vscode/extensions`), Python virtualenvs (`.local/share/virtualenvs`)
- Containers: Docker directories (`.docker`)
- SQLite: WAL and shared memory files (`*.sqlite-wal`, `*.sqlite3-wal`, `*.sqlite-shm`, `*.sqlite3-shm`)

## Installation Notes
- borgmatic installed via pipx for user account
- Version: 2.0.7
- sudo access requires full path: `/home/server/.local/bin/borgmatic`
- Repository initialized without encryption for simplicity

## Testing
- ✅ Dry run successful
- ✅ Repository initialized and accessible
- ✅ ZFS integration configured
- ✅ First backup completed successfully
- ✅ Repository integrity verified

## Database Integration
- ✅ PostgreSQL backup configured for Immich (1 database)
- ✅ SQLite backups configured for all services (9 databases)
  - Vaultwarden, Kleio, Ntfy (auth/cache), Grafana, Drone, Jellyfin (library/main), FileBrowser
- ✅ VictoriaMetrics TSDB backup via snapshot API
- **Credentials**: File-based using `{credential file}` syntax  
- **Security**: Only credential files are gitignored, config structure visible
- **Borgmatic Native**: Uses built-in database dump support + VM snapshots

## Scheduling Setup

### Server
Traditional cron job for reliable server environment:
```bash
# Add to root's crontab (sudo crontab -e)
0 2 * * * /home/server/.local/bin/borgmatic --config /home/server/backup/config.yaml
```

### XPS17 (Laptop)
Smart backup script with intelligent condition checking:
```bash
# Smart backup script: /home/bobparsons/Development/backup/smart-backup.sh
# Checks: NAS connectivity, battery level (>30% or AC), last backup time (>3h), system load
# Add to root's crontab (sudo crontab -e):
0 * * * * /home/bobparsons/Development/backup/smart-backup.sh >/dev/null 2>&1
```

### Mira (Desktop)
Traditional cron job:
```bash
# Add to root's crontab (sudo crontab -e)
0 2 * * * /home/bobparsons/.local/bin/borgmatic --config /home/bobparsons/Development/backup/config-mira.yaml
```

## Monitoring
All systems generate Prometheus metrics for backup monitoring:

### Metrics Generated
- `borgmatic_backup_success{config="hostname"}` - 1 for success, 0 for failure  
- `borgmatic_backup_last_run_timestamp` - Unix timestamp of last backup attempt

### Metric Locations
- **XPS17**: `/home/bobparsons/Development/backup/metrics/borgmatic_xps17.prom`
- **Mira**: `/var/lib/prometheus/node-exporter/borgmatic_mira.prom`
- **Server**: Via borgmatic command hooks (location TBD)

### Integration
Configure node_exporter textfile collector to scrape these metrics for alerting on backup failures and stale backups.

## Next Steps
- [ ] Test restore procedures
- [ ] Set up monitoring alerts for backup failures

## Common Commands
```bash
# Generate config template
borgmatic config generate --destination ./config-hostname.yaml

# Test configuration (requires sudo for system files)
sudo /path/to/.local/bin/borgmatic --config ./config-hostname.yaml --dry-run

# Run backup manually (requires sudo for system files)
sudo /path/to/.local/bin/borgmatic --config ./config-hostname.yaml

# Initialize repository (unencrypted)
sudo borg init --encryption=none /mnt/nas/backups/hostname

# Verify repository integrity
sudo borg check /mnt/nas/backups/hostname

# List available archives
sudo borg list /mnt/nas/backups/hostname

# Setup cron job
sudo crontab -e
# Add: 0 2 * * * /path/to/.local/bin/borgmatic --config /path/to/config-hostname.yaml
```