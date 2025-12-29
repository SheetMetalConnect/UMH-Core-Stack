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
- `kafkatopostgresqlv2` - Writer
- `grafanareader` - Read-only

## Editing Notes

- Use standard markdown links, not wikilinks
- Keep `.env.example` updated when adding env vars
- Test compose changes with `docker compose config`
