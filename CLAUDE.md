# Borgmatic Backup Setup

## Project Overview
Setting up borgmatic for automated backups with ZFS integration.

## Current Configuration
- **Config Location**: `/home/server/backup/config.yaml` (local, version controlled)
- **Repository**: `/mnt/nas-direct/backups/server` (unencrypted)
- **Retention**: 7 daily, 4 weekly, 12 monthly, 1 yearly
- **ZFS Integration**: Enabled (automatic dataset discovery)

## Source Directories
- `/home` - User data
- `/etc` - System configuration
- `/var/log` - System logs
- `/var/lib` - Application data and databases
- `/opt` - Third-party software

## Exclusion Patterns
- Cache directories (`/home/*/.cache`, `/var/cache`)
- Temporary files (`/var/tmp`, `*.tmp`)
- Development artifacts (`node_modules`, `__pycache__`, `.git/objects`)
- Package manager caches (`.npm`, `.yarn/cache`)
- System journals and log rotations

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

## Next Steps
- [ ] Test complete database backup configuration
- [ ] Set up automated scheduling (cron/systemd)
- [ ] Test restore procedures

## Commands
```bash
# Generate config locally
borgmatic config generate --destination ./config.yaml

# Test configuration (requires sudo for system files)
sudo /home/server/.local/bin/borgmatic --config ./config.yaml --dry-run

# Run backup (requires sudo for system files)
sudo /home/server/.local/bin/borgmatic --config ./config.yaml

# Initialize repository (done)
sudo borg init --encryption=none /mnt/nas-direct/backups/server

# Verify repository integrity
sudo borg check /mnt/nas-direct/backups/server

# List available archives
sudo borg list /mnt/nas-direct/backups/server
```