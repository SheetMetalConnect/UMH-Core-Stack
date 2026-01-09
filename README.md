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

**Data flows** (examples/databridges):
- Historian flow — UNS → TimescaleDB
- ERP integration — Sales orders with deduplication + history tracking
- MQTT bridges — Ingest and feedback

**UMH Core runs separately** and connects to the stack network for reliability.

## Quick Start

```bash
# 1. Configure environment
cp .env.example .env
# Edit .env: add AUTH_TOKEN from Management Console

# 2. Start infrastructure
docker compose up -d

# 3. Run UMH Core (separate for reliability)
docker run -d --restart unless-stopped --name umh-core \
  --network lve-umh-core_umh-network \
  -v umh-core-data:/data \
  -e AUTH_TOKEN=${AUTH_TOKEN} \
  management.umh.app/oci/united-manufacturing-hub/umh-core:latest

# 4. Initialize ERP schema
docker exec -i timescaledb psql -U postgres -d umh_v2 \
  < examples/databridges/sql/02-erp-schema.sql

# 5. Deploy flows via Management Console
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
| PostgreSQL | localhost:5432 | kafkatopostgresqlv2 / umhcore |

## Architecture

```
External Systems
      │
      ▼ MQTT
┌─────────────┐     ┌──────────────┐
│  HiveMQ CE  │────▶│   UMH Core   │
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
        └─────────────────────┘   └──────────┘
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

## Database Schema

**Historian tables** (auto-created):
- `asset` — Asset registry (id, asset_name, location)
- `tag` — Numeric time-series (hypertable)
- `tag_string` — String time-series (hypertable)

**ERP tables** (run sql/02-erp-schema.sql):
- `erp_sales_order` — Current state (upsert)
- `erp_sales_order_history` — Audit trail (append-only)

## Structure

```
.
├── docker-compose.yaml          # Infrastructure stack
├── .env.example                 # Environment template
├── configs/                     # Service configurations
│   ├── grafana/provisioning/    # Datasource auto-provisioned
│   ├── nodered/settings.js      # Projects + Multiplayer enabled
│   └── timescaledb-init/        # Schema initialization
├── examples/
│   ├── databridges/             # Data flows + SQL
│   │   ├── flows/               # UMH Core flows
│   │   ├── sql/                 # ERP schema
│   │   └── classic/             # Reference: k8s format
│   └── historian/               # TimescaleDB compose overlay
└── docs/                        # Additional documentation
```

## Production Notes

- Change default password `umhcore` everywhere: `grep -r "umhcore" . --include="*.yaml"`
- All images use `:latest` — run `docker compose pull` for updates
- UMH Core runs separately for reliability (restart independently)
- See [docs/security.md](docs/security.md) for hardening

## Related

- [UMH Documentation](https://docs.umh.app/)
- [Management Console](https://management.umh.app/)
- [UMH Repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub)
