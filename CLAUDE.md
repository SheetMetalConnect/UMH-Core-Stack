# Agent Instructions

Docker Compose stack for [UMH Core](https://github.com/united-manufacturing-hub/united-manufacturing-hub).

## Repo Structure

```
.
├── README.md               # Public intro
├── CLAUDE.md               # Agent instructions (you are here)
├── docker-compose.yaml     # Core stack
├── .env.example            # Environment template
├── configs/                # Service configs
│   ├── nginx.conf
│   ├── nodered/settings.js
│   ├── grafana/provisioning/
│   └── timescaledb-init/
├── docs/                   # Documentation
│   ├── setup.md            # Initial setup guide
│   ├── historian.md        # TimescaleDB addon
│   ├── historian-flow.md   # Pre-built historian bridge (dataFlow)
│   └── networking.md       # Port and service info
└── examples/historian/     # TimescaleDB + Grafana addon
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

## Historian Bridge (dataFlow)

The historian bridge writes MQTT data to TimescaleDB. It's adapted from UMH Classic's `kafka_to_postgresql_historian_bridge`.

**How to deploy:**
1. Copy the YAML from `docs/historian-flow.md`
2. Paste into Management Console under dataFlows
3. UMH Core automatically deploys the bridge

The bridge uses Benthos/Redpanda Connect components:
- `mqtt` input - subscribes to `umh/#`
- `branch` processor with `cached` - caches asset IDs
- `sql_raw` processor - looks up/creates asset IDs
- `switch` output - routes numeric→`tag`, string→`tag_string`
- `sql_insert` output - batched inserts

## Editing Notes

- Use standard markdown links, not wikilinks
- Keep `.env.example` updated when adding env vars
- Test compose changes with `docker compose config`
- dataFlows are configured via Management Console, not direct config editing
