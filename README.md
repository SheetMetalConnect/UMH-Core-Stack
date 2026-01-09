# UMH Core Stack

Turn-key Docker Compose stack for [United Manufacturing Hub](https://github.com/united-manufacturing-hub/united-manufacturing-hub) with historian and ERP integration.

## What This Provides

**Infrastructure stack** (docker-compose):
- HiveMQ CE — MQTT broker
- TimescaleDB — Time-series database with pre-configured schema
- Grafana — Dashboards with datasource pre-configured  
- PgBouncer — Connection pooling
- Node-RED — Flow programming (Projects + Multiplayer enabled)
- Portainer — Container management
- NGINX — Reverse proxy for webhooks

**Data flows** (examples/databridges):
- Historian flow — UNS → TimescaleDB
- ERP integration — Sales orders with deduplication + history tracking
- MQTT bridges — Ingest and feedback

**AI Integration** (examples/mcp):
- Node-RED MCP server — AI assistance for flow development
- Grafana MCP server — AI-powered dashboard creation

**UMH Core runs separately** and connects to the stack network for reliability.

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env: add AUTH_TOKEN from Management Console

# 2. Start infrastructure stack
docker compose up -d

# 3. Start historian addon (optional but recommended)
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d

# 4. Run UMH Core (separate container for reliability)
# Note: Network name is automatically prefixed with project directory name
docker run -d --restart unless-stopped --name umh-core \
  --network lve-umh-core_umh-network \
  -v umh-core-data:/data \
  -e AUTH_TOKEN=${AUTH_TOKEN} \
  management.umh.app/oci/united-manufacturing-hub/umh-core:latest

# 5. Initialize ERP schema (if using ERP flows)
docker exec -i timescaledb psql -U postgres -d umh_v2 \
  < examples/databridges/sql/02-erp-schema.sql

# 6. Deploy flows via Management Console
#    Data Flows → Standalone → Add → Advanced Mode
#    Paste content from examples/databridges/flows/
```

## Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / umhcore |
| Node-RED | http://localhost:1880 | — |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT | localhost:1883 | — |
| MQTT WebSocket | localhost:8083 | — |
| PostgreSQL (via PgBouncer) | localhost:5432 | postgres / umhcore |
| NGINX (webhooks) | http://localhost:8081 | — |

**Important**: PostgreSQL is only accessible when running the historian addon.

## Architecture

```
External Systems
      │
      ▼ MQTT (1883) / HTTP (8081)
┌─────────────┐     ┌──────────────┐
│  HiveMQ CE  │────▶│   UMH Core   │
│   + NGINX   │     │  (separate)  │
└─────────────┘     └──────┬───────┘
                           │ UNS (Kafka)
                           ▼
                    ┌──────────────┐
                    │  Data Flows  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │Historian │ │   ERP    │ │ Feedback │
        │  Flow    │ │  Flows   │ │  Flow    │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             ▼            ▼            ▼
        ┌─────────────────────┐   ┌──────────┐
        │    TimescaleDB      │   │   MQTT   │
        │  tag / erp_* tables │   │ feedback │
        └──────────┬──────────┘   └──────────┘
                   │
                   ▼
              ┌─────────┐
              │ Grafana │
              └─────────┘
```

## Data Flow Pattern

**Historian**: Time-series data flows directly to TimescaleDB.

**ERP Integration** (Pattern C — local cache with change detection):
1. External system publishes to `_sales_order.process`
2. Process flow compares against database
3. Republishes as `.create`, `.update`, or `.duplicate`
4. Persistence flow upserts current state + appends to history
5. Feedback flow notifies external systems via MQTT

This enables event-driven architecture with full history for process mining.

See [docs/integration-patterns.md](docs/integration-patterns.md) for detailed pattern explanations.

## Database Schema

**Historian tables** (auto-created on first startup):
- `asset` — Asset registry (id, asset_name, location)
- `tag` — Numeric time-series (hypertable, compressed after 7 days)
- `tag_string` — String time-series (hypertable, compressed after 7 days)

**ERP tables** (run sql/02-erp-schema.sql to create):
- `erp_sales_order` — Current state (upsert)
- `erp_sales_order_history` — Audit trail (append-only)

**Database users**:
- `postgres` — Superuser (password: umhcore)
- `kafkatopostgresqlv2` — Write access for data flows (password: umhcore)
- `grafanareader` — Read-only for Grafana (password: umhcore)

## Repository Structure

```
.
├── README.md                    # This file
├── PROJECT.md                   # Project overview and architecture
├── CLAUDE.md                    # Agent instructions
├── docker-compose.yaml          # Core infrastructure stack
├── .env.example                 # Environment template
├── configs/                     # Service configurations
│   ├── nginx.conf               # Reverse proxy config
│   ├── grafana/provisioning/    # Datasource auto-provisioned
│   ├── nodered/settings.js      # Projects + Multiplayer enabled
│   └── timescaledb-init/        # Schema initialization
│       ├── 00-create-users.sh   # Database users
│       └── 01-init-schema.sql   # Tables and hypertables
├── examples/
│   ├── databridges/             # Data flows + SQL
│   │   ├── README.md            # Flow documentation
│   │   ├── flows/               # UMH Core data flows (deploy these)
│   │   ├── sql/                 # Database schemas
│   │   └── classic/             # Reference: k8s format
│   └── historian/               # TimescaleDB addon
│       ├── README.md            # Historian setup guide
│       ├── docker-compose.historian.yaml
│       └── .env.historian.example
└── docs/                        # Additional documentation
    ├── integration-patterns.md  # Pattern A/B/C explained
    ├── historian.md             # TimescaleDB addon details
    ├── networking.md            # Ports and connectivity
    └── ...
```

## Production Checklist

- [ ] Change default password `umhcore` everywhere
  ```bash
  # Generate secure password
  openssl rand -base64 32
  
  # Find all occurrences
  grep -r "umhcore" . --include="*.yaml" --include="*.example" --include="*.md"
  ```
- [ ] Set `AUTH_TOKEN` from Management Console
- [ ] Configure TLS/SSL for external endpoints
- [ ] Restrict NGINX CORS headers (currently allows `*`)
- [ ] Review and adjust retention policies (default: 90 days)
- [ ] Set up database backups
- [ ] Configure resource limits in compose files
- [ ] Review security documentation: [docs/security.md](docs/security.md)

## Network Configuration

Docker Compose automatically prefixes the network name with the project directory name:
- Directory: `lve-umh-core`
- Network in compose: `umh-network`
- Actual network name: `lve-umh-core_umh-network`

UMH Core must connect to this prefixed network name. To find the exact name:
```bash
docker network ls | grep umh
```

## Updating

```bash
# Pull latest images
docker compose pull
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml pull

# Restart services
docker compose up -d
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d

# Update UMH Core
docker stop umh-core
docker rm umh-core
docker pull management.umh.app/oci/united-manufacturing-hub/umh-core:latest
# Then re-run the docker run command from Quick Start
```

## Related Resources

- [UMH Documentation](https://docs.umh.app/)
- [Management Console](https://management.umh.app/)
- [UMH Core Repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub)
- [PROJECT.md](PROJECT.md) — Architecture and design decisions
- [docs/integration-patterns.md](docs/integration-patterns.md) — ERP integration patterns
- [docs/ai-development-guide.md](docs/ai-development-guide.md) — AI-assisted development with MCP
