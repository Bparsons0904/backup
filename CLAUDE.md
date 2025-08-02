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
- **Type**: Filesystem backup only
- **Status**: ✅ Complete

### Mira
- **Config**: `config-mira.yaml`
- **Repository**: `/mnt/nas/backups/mira` (unencrypted)
- **Type**: Filesystem backup only
- **Status**: ✅ Complete

## Common Configuration
- **Retention**: 7 daily, 4 weekly, 12 monthly, 1 yearly
- **Installation**: borgmatic via pipx (version 2.0.7)
- **Scheduling**: Cron jobs (daily backups)

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

## Scheduling Setup
All computers use cron for automated daily backups:

```bash
# Add to root's crontab (sudo crontab -e)
# Server (with database backups)
0 2 * * * /home/server/.local/bin/borgmatic --config /home/server/backup/config.yaml

# XPS17 (filesystem only)  
0 2 * * * /home/user/.local/bin/borgmatic --config /path/to/config-xps17.yaml

# Mira (filesystem only)
0 2 * * * /home/bobparsons/.local/bin/borgmatic --config /home/bobparsons/Development/backup/config-mira.yaml
```

## Next Steps
- [ ] Test restore procedures

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