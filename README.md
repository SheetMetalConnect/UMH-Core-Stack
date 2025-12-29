# UMH Core Stack

A ready-to-run Docker Compose stack for [United Manufacturing Hub (UMH)](https://github.com/united-manufacturing-hub/united-manufacturing-hub) with batteries included.

## What's Included

| Component | Purpose |
|-----------|---------|
| **UMH Core** | Edge gateway with embedded Kafka (Redpanda) and Unified Namespace |
| **HiveMQ CE** | MQTT broker for device connectivity |
| **Node-RED** | Flow-based programming with Projects + Multiplayer enabled |
| **TimescaleDB** | Time-series database for historian storage |
| **Grafana** | Dashboards with TimescaleDB datasource pre-configured |
| **PgBouncer** | Database connection pooling |
| **Portainer** | Container management UI |
| **NGINX** | Reverse proxy for webhooks |

This stack extends the [official UMH Docker Compose setup](https://github.com/united-manufacturing-hub/united-manufacturing-hub/pull/2352) with additional tooling for rapid prototyping.

## Pre-configured Features

**Node-RED** (`configs/nodered/settings.js`):
- **Projects**: Git-backed flow versioning enabled
- **Multiplayer**: Real-time collaboration mode enabled
- **External Modules**: Install npm packages directly in function nodes

**Grafana** (`configs/grafana/provisioning/`):
- **TimescaleDB Datasource**: Auto-provisioned on startup, ready to query

**TimescaleDB** (`configs/timescaledb-init/`):
- **Schema**: `asset`, `tag`, `tag_string` tables with hypertables
- **Users**: Writer (`kafkatopostgresqlv2`) and reader (`grafanareader`) pre-created
- **Compression**: Automatic after 7 days

> **Default Password:** All services use `umhcore` as the default password for easy development setup. For production, search and replace all occurrences: `grep -r "umhcore" . --include="*.yaml" --include="*.example" --include="*.md"`

> **Latest Images:** All services use `:latest` tags for easy updates. Run `docker compose pull` regularly to get the newest versions.

## Quick Start

```bash
# Copy and configure environment
cp .env.example .env
# Edit .env and add your AUTH_TOKEN from Management Console

# Start the full stack
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

## Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Node-RED | http://localhost:1880 | - |
| Grafana | http://localhost:3000 | admin / umhcore |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT Broker | localhost:1883 | - |

## Historian Bridge

This stack includes a **ready-to-paste historian bridge** that writes MQTT data to TimescaleDB. It's adapted from the [UMH Classic kafka_to_postgresql_historian_bridge](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml).

To enable it:

1. Open **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Paste the config from [docs/historian-flow.md](docs/historian-flow.md)

Works out of the box (default password: `umhcore`). See [Historian](docs/historian.md) for schema details.

## Documentation

- [Overview](docs/overview.md) - Architecture and concepts
- [Operations](docs/operations.md) - Quick start and commands
- [Networking](docs/networking.md) - Ports, internal DNS, LAN access
- [Historian](docs/historian.md) - TimescaleDB setup and database schema
- [Historian Flow](docs/historian-flow.md) - MQTT → TimescaleDB bridge config
- [Extensions](docs/extensions.md) - Optional addons (NocoDB, Appsmith, n8n, etc.)
- [Security](docs/security.md) - Production hardening notes

## Repo Structure

```
.
├── docker-compose.yaml     # Core stack
├── .env.example            # Environment template
├── configs/                # Service configurations
├── docs/                   # Documentation
└── examples/historian/     # TimescaleDB + Grafana addon
```

## Related

- [UMH Core Repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub)
- [UMH Documentation](https://umh.docs.umh.app/)
- [Management Console](https://management.umh.app/)

## License

This deployment configuration is provided as-is. UMH Core and its components have their own licenses - see the [UMH repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub) for details.
