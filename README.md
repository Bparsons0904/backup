## Kopia Backup Service Deployment Plan

## Overview

Deploy Kopia as a containerized backup service integrated with existing infrastructure:

- **Deployment**: Drone CI/CD pipeline (like other services)
- **Access**: Via Traefik reverse proxy at `backup.bobparsons.dev`
- **Storage**: NAS repository at `/mnt/nas-direct/backups/`
- **Strategy**: Nightly automated backups with brief service downtime

## Docker Compose Configuration

### Base Configuration (Updated)

```yaml
services:
  kopia:
    image: kopia/kopia:latest
    hostname: backup-server
    container_name: kopia
    restart: unless-stopped
    user: root
    command:
      - server
      - start
      - --address=0.0.0.0:51515
      - --server-username=admin
      - --server-password=${KOPIA_SERVER_PASSWORD}
      - --override-hostname=backup-server
    environment:
      KOPIA_PASSWORD: ${KOPIA_REPO_PASSWORD}
      USER: "server" # Updated from "mini"
      TZ: "America/Chicago" # Set timezone for logs
    volumes:
      - ./config:/app/config
      - ./cache:/app/cache
      - ./logs:/app/logs
      - /mnt/nas-direct/backups:/repository # Updated path
      - /home/server:/data/home:ro # Updated path
      - /var/lib/docker/volumes:/data/docker-volumes:ro
      - /etc:/data/etc:ro # System configs
      - /var/run/docker.sock:/var/run/docker.sock # For container management
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.kopia.rule=Host(`backup.bobparsons.dev`)"
      - "traefik.http.routers.kopia.entrypoints=https"
      - "traefik.http.routers.kopia.tls.certresolver=letsencrypt"
      - "traefik.http.services.kopia.loadbalancer.server.port=51515"
      - "traefik.docker.network=traefik"
    networks:
      - traefik

networks:
  traefik:
    external: true
```

## Key Changes Made

### 1. **Traefik Integration**

- Added Traefik labels for reverse proxy
- Exposed on `backup.bobparsons.dev`
- SSL via Let's Encrypt
- Removed localhost port binding (access via Traefik only)

### 2. **Updated Paths**

- Repository: `/mnt/nas-direct/backups` (matches your NAS mount)
- Home directory: `/home/server` (your actual user)
- Added Docker volumes mount for container data backup

### 3. **Security Considerations**

- Removed `--insecure` flag (will be behind Traefik with SSL)
- Docker socket access for container management during backups
- Read-only mounts where possible

## Environment Variables Setup

### `.env` file

```env
KOPIA_SERVER_PASSWORD=your_secure_admin_password
KOPIA_REPO_PASSWORD=your_secure_repo_encryption_password
```

## Deployment Steps

### 1. **Repository Creation**

Create Git repository with:

```
kopia/
├── docker-compose.yml
├── .env.example
├── .drone.yml
├── backup-script.sh  # Automated backup script
└── README.md
```

### 2. **Initialize Repository**

After first deployment, initialize the Kopia repository:

```bash
# Access the container
docker exec -it kopia bash

# Initialize repository (one-time setup)
kopia repository create filesystem --path=/repository
```

### 3. **Drone Pipeline**

Standard deployment pipeline like other services:

```yaml
kind: pipeline
type: docker
name: kopia-deploy

steps:
  - name: deploy
    image: docker:24-cli
    commands:
      - apk add --no-cache docker-compose
      - docker-compose down || true
      - docker-compose pull
      - docker-compose up -d
    when:
      branch:
        - main
      event:
        - push
```

## Backup Script Integration

### Automated Backup Script

Location: `~/kopia/backup-script.sh`

```bash
#!/bin/bash
# backup-script.sh - Automated nightly backup with service management

set -e

# Services to stop during backup
CRITICAL_SERVICES=(
    "photos/docker-compose.yml:immich_postgres"
    "vaultwarden/docker-compose.yml:vaultwarden"
    "jellyfin/docker-compose.yml:jellyfin"
)

echo "$(date): Starting backup process..."

# Stop critical services
for service in "${CRITICAL_SERVICES[@]}"; do
    compose_file="${service%:*}"
    service_name="${service#*:}"
    echo "Stopping $service_name..."
    docker-compose -f "$HOME/$compose_file" stop "$service_name" || true
done

# Wait for services to fully stop
sleep 10

# Trigger Kopia backup via API
curl -X POST \
    -u admin:${KOPIA_SERVER_PASSWORD} \
    -H "Content-Type: application/json" \
    http://localhost:51515/api/v1/snapshots \
    -d '{
        "source": {
            "path": "/data/home",
            "host": "backup-server"
        }
    }'

# Restart services
for service in "${CRITICAL_SERVICES[@]}"; do
    compose_file="${service%:*}"
    service_name="${service#*:}"
    echo "Starting $service_name..."
    docker-compose -f "$HOME/$compose_file" start "$service_name"
done

echo "$(date): Backup process completed"
```

### Cron Schedule

```bash
# Add to crontab: backup at 2 AM daily
0 2 * * * /home/server/kopia/backup-script.sh >> /var/log/kopia-backup.log 2>&1
```

## Repository Structure

### Backup Targets

```
/data/home/              # /home/server (configs, docker-compose files)
├── traefik/             # Traefik configuration + SSL certs
├── drone/               # Drone CI data
├── jellyfin/            # Jellyfin config/cache
├── photos/              # Immich data
├── vaultwarden/         # Password manager data
└── ...                  # All other service configs

/data/docker-volumes/    # Docker volume data
├── drone_data/          # Drone database
├── immich_pgdata/       # Postgres database
└── ...                  # Other volume data

/data/etc/               # System configurations
├── fstab                # Mount configurations
├── netplan/             # Network setup
└── ...                  # Other system configs
```

## Initial Setup Checklist

### Pre-deployment

- [ ] Create `kopia` directory in home folder
- [ ] Set up Git repository with configs
- [ ] Configure `.env` with strong passwords
- [ ] Test NAS mount path accessibility

### Post-deployment

- [ ] Access Kopia UI at `backup.bobparsons.dev`
- [ ] Initialize repository via UI or CLI
- [ ] Configure backup policies and schedules
- [ ] Test manual backup of small directory
- [ ] Set up cron job for automated backups
- [ ] Test service stop/start script

### Verification

- [ ] Verify backups are created in `/mnt/nas-direct/backups/`
- [ ] Test restore of a small file
- [ ] Monitor backup logs for errors
- [ ] Confirm services restart properly after backup

## Security Notes

### Network Security

- Kopia only accessible via HTTPS through Traefik
- No direct port exposure to internet
- Repository encryption with separate password

### File Permissions

- Read-only mounts where possible
- Docker socket access only for backup operations
- Separate config/cache/logs directories

## Future Enhancements

### Additional Backup Targets

- [ ] Add system logs (`/var/log`)
- [ ] Add Docker images backup
- [ ] Consider offsite backup replication

### Monitoring

- [ ] Integrate backup success/failure notifications
- [ ] Add backup metrics to monitoring stack
- [ ] Set up alerts for backup failures

### Automation

- [ ] Pre-backup health checks
- [ ] Post-backup verification
- [ ] Automatic cleanup of old snapshots

## Expected Benefits

### Reliability

- Consistent database backups (no corruption)
- Automated scheduling reduces human error
- Point-in-time recovery capabilities

### Integration

- Managed like other services via Drone CI/CD
- SSL-secured web interface
- Centralized configuration management

### Scalability

- Easy to add new backup targets
- Can extend to backup other servers
- Repository can be replicated to multiple locations backup
