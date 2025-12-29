# UMH Core Stack

A ready-to-run Docker Compose stack for [United Manufacturing Hub (UMH)](https://github.com/united-manufacturing-hub/united-manufacturing-hub) with batteries included.

## What's Included

| Component | Purpose |
|-----------|---------|
| **UMH Core** | Edge gateway with embedded Kafka (Redpanda) and Unified Namespace |
| **HiveMQ CE** | MQTT broker for device connectivity |
| **Node-RED** | Flow-based programming and data transformation |
| **TimescaleDB** | Time-series database for historian storage |
| **Grafana** | Dashboards and visualization |
| **PgBouncer** | Database connection pooling |
| **Portainer** | Container management UI |
| **NGINX** | Reverse proxy for webhooks |

This stack extends the [official UMH Docker Compose setup](https://github.com/united-manufacturing-hub/united-manufacturing-hub/pull/2352) with additional tooling for rapid prototyping.

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
| Grafana | http://localhost:3000 | admin / admin |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT Broker | localhost:1883 | - |

## Historian Bridge (Pre-Built)

This stack includes a **pre-configured historian bridge** that writes MQTT data to TimescaleDB automatically. It's adapted from the [UMH Classic kafka_to_postgresql_historian_bridge](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml).

The bridge is defined in `configs/config.yaml.example` and runs as a UMH Core standalone flow. To enable it:

1. Copy the example config: `cp configs/config.yaml.example data/config.yaml`
2. Update the database password to match your `HISTORIAN_WRITER_PASSWORD`
3. Restart UMH Core

See [Historian](docs/historian.md) for schema details and [Historian Flow](docs/historian-flow.md) for customization.

## Documentation

- [Overview](docs/overview.md) - Architecture and concepts
- [Operations](docs/operations.md) - Quick start and commands
- [Networking](docs/networking.md) - Ports, internal DNS, LAN access
- [Historian](docs/historian.md) - TimescaleDB setup and database schema
- [Historian Flow](docs/historian-flow.md) - MQTT → TimescaleDB bridge config
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
