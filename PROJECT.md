# Project Overview

## Purpose

LVE-UMH-CORE is a turn-key deployment package for United Manufacturing Hub (UMH) Core providing:

1. **Infrastructure stack** — Docker Compose with MQTT, TimescaleDB, Grafana, Node-RED, PgBouncer, Portainer
2. **Historian** — Time-series ingestion from UNS to TimescaleDB
3. **ERP Integration** — Pattern C implementation with change detection and full history tracking

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Docker Compose Stack                        │
│  ┌──────────┐ ┌────────────┐ ┌─────────┐ ┌──────────┐          │
│  │ HiveMQ   │ │TimescaleDB │ │ Grafana │ │ Node-RED │  ...     │
│  └──────────┘ └────────────┘ └─────────┘ └──────────┘          │
└─────────────────────────────────────────────────────────────────┘
        │                │
        │ MQTT           │ SQL
        │                │
┌───────┴───────┐        │
│   UMH Core    │────────┘
│  (separate)   │  UNS (Kafka) → Data Flows → TimescaleDB
└───────────────┘
```

**UMH Core runs separately** from the stack for reliability — can restart independently.

## Data Patterns

### Historian
- UNS → TimescaleDB
- Time-series tag values
- Tables: `asset`, `tag`, `tag_string`

### ERP Integration (Pattern C)
- Preload ERP data into local database
- Detect changes via deduplication (compare incoming vs stored)
- Track full history of every state change
- Enables process mining on historical data
- Tables: `erp_sales_order`, `erp_sales_order_history`

See [docs/integration-patterns.md](docs/integration-patterns.md) for pattern details.

## Deployment

```bash
# 1. Start infrastructure
docker compose up -d

# 2. Run UMH Core separately
docker run -d --name umh-core \
  --network lve-umh-core_umh-network \
  -e AUTH_TOKEN=${AUTH_TOKEN} \
  management.umh.app/oci/united-manufacturing-hub/umh-core:latest

# 3. Initialize ERP schema
docker exec -i timescaledb psql -U postgres -d umh_v2 \
  < examples/databridges/sql/02-erp-schema.sql

# 4. Deploy flows via Management Console
# Paste from examples/databridges/flows/
```

## Repository Structure

```
LVE-UMH-CORE/
├── README.md                    # Quick start
├── PROJECT.md                   # This file
├── docker-compose.yaml          # Infrastructure stack
├── .env.example
├── configs/                     # Service configurations
├── docs/
│   ├── integration-patterns.md  # Pattern A/B/C explained
│   ├── historian.md
│   └── ...
└── examples/
    ├── databridges/
    │   ├── flows/               # UMH Core flows (deploy these)
    │   ├── sql/                 # Database schema
    │   └── classic/             # Reference: k8s format
    └── historian/               # TimescaleDB compose overlay
```

## Flows

| Flow | Purpose |
|------|---------|
| `historian.yaml` | UNS → TimescaleDB (time-series) |
| `mqtt_to_uns_bridge.yaml` | External MQTT → UNS |
| `sales_order_process.yaml` | Deduplication logic |
| `sales_order_to_timescale.yaml` | Persist + history tracking |
| `timescale_delete.yaml` | Delete handling |
| `uns_to_mqtt_feedback.yaml` | State change notifications |

## Asset Model

All flows use consistent mapping:

```
Topic: umh.v1.acme.chicago.packaging.line1._historian.temp
                                     └────┘ └────────────┘
                                   asset_name  location path above

→ asset_name = 'line1'
→ location   = 'acme.chicago.packaging'
```

The `get_asset_id()` SQL function produces identical results.

## Key Design Decisions

1. **UMH Core separate** — Reliability, independent restarts
2. **Pattern C for ERP** — Full history, process mining capability
3. **Deduplication** — Don't flood with unchanged data
4. **Event-driven** — Every change is an event (create/update/delete)
5. **Single source of truth** — One location for flows, no duplicates
