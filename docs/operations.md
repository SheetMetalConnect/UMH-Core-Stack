# Operations

## Prerequisites

1. Docker and Docker Compose v2 installed
2. Management Console account for UMH Core

## Quick Start

This repo is already the full stack. For the official UMH setup guide, see [docs.umh.app](https://docs.umh.app/production/deployment/docker-compose).

1) Configure environment

```bash
cp .env.example .env
```

Edit `.env` and set:
- `AUTH_TOKEN` - from Management Console
- `POSTGRES_PASSWORD` - database superuser password (historian)
- `HISTORIAN_WRITER_PASSWORD` - writer password (historian)
- `HISTORIAN_READER_PASSWORD` - reader password (historian)
- `GF_ADMIN_PASSWORD` - Grafana admin password (historian)

Set credentials once before first deployment; the database init scripts apply them on first boot.

2) Start the full stack (one command)

```bash
docker compose up -d
```

3) Verify services

```bash
docker compose ps
```

## Config File Editing (Management Console)

UMH Core reads `/data/config.yaml` and hot-reloads valid changes. For managed
instances, prefer the Management Console **Config File** editor (with Local
File Sync) to push YAML changes. Direct local edits only affect this host
unless synced via the console. This stack does not preconfigure data flows;
create bridges and historian flows in the Management Console.

## Access Services

| Service | URL | Default Credentials |
|---------|-----|---------------------|
| NGINX (webhooks) | http://localhost:80 | - |
| NGINX (HTTPS) | https://localhost:443 | - |
| Grafana | http://localhost:3000 | admin / changeme |
| Node-RED | http://localhost:1880 | - |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT | tcp://localhost:1883 | No auth (dev mode) |
| PgBouncer | tcp://localhost:5432 | Uses `POSTGRES_*` + historian users |
| MCP (Postgres) | http://localhost:3003 | - |

Node-RED is configured with Projects + Multiplayer enabled in `configs/nodered/settings.js`.

> **Note:** Node-RED displays a warning on startup about mounting a volume to `/data`. This warning can be safely ignored - the stack uses a named volume (`nodered-data`) which correctly persists all flows, configurations, and installed nodes across container restarts and upgrades.

For LAN access, replace `localhost` with the host IP (see `docs/networking.md`).

## Common Commands

```bash
# Start all services
docker compose up -d

# View logs
docker compose logs -f

# View specific service logs
docker compose logs -f umh

# Check service status
docker compose ps

# Stop all services
docker compose down

# Stop and remove volumes (WARNING: deletes data)
docker compose down -v

# Restart a specific service
docker compose restart grafana

# Pull latest images
docker compose pull
```

## Updating UMH Core

Update the image tag in `docker-compose.yaml` and restart:

```bash
# Edit docker-compose.yaml → umh service → image tag
docker compose pull umh && docker compose up -d
```

Data is preserved in named Docker volumes.

## See Also

- [Networking](networking.md) — Port mappings, DNS, access patterns
- [Troubleshooting](troubleshooting.md) — Common issues and fixes
- [Deployment Lessons](deployment-lessons.md) — Production-tested tips
- [Historian](historian.md) — TimescaleDB setup and backup
