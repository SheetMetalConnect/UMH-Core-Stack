# Agent Instructions

Docker Compose stack for [UMH Core](https://github.com/united-manufacturing-hub/united-manufacturing-hub).

## Repo Structure

```
.
├── README.md               # Public intro
├── PROJECT.md              # Project overview and goals
├── CLAUDE.md               # Agent instructions (you are here)
├── docker-compose.yaml     # Core stack
├── .env.example            # Environment template
├── configs/                # Service configs
│   ├── nginx.conf
│   ├── nodered/settings.js
│   ├── grafana/provisioning/
│   └── timescaledb-init/
├── docs/                   # Documentation
│   ├── integration-patterns.md  # Pattern A/B/C explanation
│   ├── historian.md        # TimescaleDB addon
│   ├── networking.md       # Port and service info
│   └── ...
└── examples/
    ├── databridges/
    │   ├── README.md
    │   ├── flows/          # UMH Core flows (6 yaml files)
    │   ├── sql/            # Database schema (02-erp-schema.sql)
    │   └── classic/        # Reference: k8s format (5 yaml + README)
    └── historian/          # TimescaleDB + Grafana addon
```

## Commands

```bash
# Start full stack (core + historian)
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d

# View logs
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml logs -f

# Stop
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml down
```

## Services & Ports

| Service | Port | Internal DNS |
|---------|------|--------------|
| NGINX (webhooks) | 8081 | `nginx:8080` |
| HiveMQ MQTT | 1883 | `hivemq:1883` |
| HiveMQ WebSocket | 8083 | `hivemq:8000` |
| Node-RED | 1880 | `nodered:1880` |
| Grafana | 3000 | `grafana:3000` |
| Portainer | 9000 | `portainer:9000` |
| PgBouncer | 5432 | `pgbouncer:5432` |
| TimescaleDB | (internal) | `timescaledb:5432` |
| UMH Core | (internal) | `umh-core:8040` |

## Pre-configured Features

**Node-RED** (`configs/nodered/settings.js`):
- Projects enabled (Git-backed flow versioning)
- Multiplayer enabled (real-time collaboration)
- External modules allowed in function nodes

**Grafana** (`configs/grafana/provisioning/`):
- TimescaleDB datasource auto-provisioned

**TimescaleDB** (`configs/timescaledb-init/`):
- Schema with `asset`, `tag`, `tag_string` hypertables
- ERP schema with `erp_sales_order`, `erp_sales_order_history` tables
- Writer/reader users pre-created
- Compression enabled (7 days)

## Gitignored (local only)

- `.env` - Contains AUTH_TOKEN
- `data/` - Runtime data, logs, config.yaml

## External Resources

- **UMH Core**: https://github.com/united-manufacturing-hub/united-manufacturing-hub
- **UMH Docs**: https://umh.docs.umh.app/
- **Management Console**: https://management.umh.app/

## Database (Historian)

Tables in `umh_v2`:
- `asset` - Asset metadata
- `tag` - Numeric time-series
- `tag_string` - Text time-series
- `erp_sales_order` - Current ERP state (Pattern C)
- `erp_sales_order_history` - Full change history (Pattern C)

Users:
- `postgres` - Superuser
- `kafkatopostgresqlv2` - Writer (password: `umhcore`)
- `grafanareader` - Read-only (password: `umhcore`)

## Password Convention

All services use `umhcore` as the default password for easy development:

```bash
# Find all password occurrences for production replacement
grep -r "umhcore" . --include="*.yaml" --include="*.example" --include="*.md" --include="*.sh"
```

For production, replace all `umhcore` with secure passwords.

## Data Flows (Bridges)

All flows are in `examples/databridges/flows/`. Deploy via Management Console:

| Flow | Purpose |
|------|---------|
| `historian.yaml` | UNS → TimescaleDB (time-series) |
| `mqtt_to_uns_bridge.yaml` | External MQTT → UNS |
| `sales_order_process.yaml` | Deduplication logic |
| `sales_order_to_timescale.yaml` | Persist + history tracking |
| `timescale_delete.yaml` | Delete handling |
| `uns_to_mqtt_feedback.yaml` | State change notifications |

**How to deploy:**
1. Copy the YAML from `examples/databridges/flows/<flow-name>.yaml`
2. Paste into Management Console under dataFlows
3. UMH Core automatically deploys the bridge

The flows use Benthos/Redpanda Connect components with consistent asset mapping.

## Integration Patterns

See `docs/integration-patterns.md` for details on:
- **Pattern A**: Direct write (UNS → TimescaleDB)
- **Pattern B**: Pull on demand (UNS triggers fetch from ERP)
- **Pattern C**: Preload + change detection (used in this repo)

Pattern C enables process mining by tracking full history of state changes.

## Editing Notes

- Use standard markdown links, not wikilinks
- Keep `.env.example` updated when adding env vars
- Test compose changes with `docker compose config`
- dataFlows are configured via Management Console, not direct config editing
- All flows are in `examples/databridges/flows/` - single source of truth
