# Operations

## Prerequisites

1. Docker and Docker Compose v2 installed
2. Management Console account for UMH Core

## Quick Start

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

2) Start the stack

Turnkey stack (core + NGINX + connectivity + historian + PgBouncer + Grafana):

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

Core-only dev mode (no historian):

```bash
docker compose up -d
```

3) Verify services

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml ps
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
| NGINX (webhooks) | http://localhost:8081 | - |
| Grafana | http://localhost:3000 | admin / admin |
| Node-RED | http://localhost:1880 | - |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT | tcp://localhost:1883 | No auth (dev mode) |
| PgBouncer | tcp://localhost:5432 | Uses `POSTGRES_*` + historian users |

Node-RED is configured with Projects + Multiplayer enabled in `configs/nodered/settings.js`.

> **Note:** Node-RED displays a warning on startup about mounting a volume to `/data`. This warning can be safely ignored - the stack uses a named volume (`nodered-data`) which correctly persists all flows, configurations, and installed nodes across container restarts and upgrades.

For LAN access, replace `localhost` with the host IP (see `docs/networking.md`).

## Common Commands

```bash
# Start all services
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d

# View logs
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml logs -f

# View specific service logs
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml logs -f umh-core

# Check service status
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml ps

# Stop all services
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml down

# Stop and remove volumes (WARNING: deletes data)
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml down -v

# Restart a specific service
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml restart grafana

# Pull latest images
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml pull
```

## See Also

- [Overview](overview.md) - Architecture and concepts
- [Networking](networking.md) - Ports, internal DNS, LAN access
- [Historian Flow](historian-flow.md) - Configure MQTT to TimescaleDB
- [Troubleshooting](troubleshooting.md) - Common issues and fixes
