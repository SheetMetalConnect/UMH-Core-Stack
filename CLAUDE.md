# UMH Core Starter Kit -- Claude Code Context

Docker Compose stack for [UMH Core](https://docs.umh.app/) with batteries-included configuration.

## Stack Architecture

**Official UMH:** UMH Core (latest), TimescaleDB 2.24.0-pg17, Grafana 12.3.0
**Addons:** HiveMQ CE (MQTT), Node-RED, Portainer, NGINX

| Service | Port | Internal DNS |
|---------|------|--------------|
| UMH Core | (internal) | `umh:8080` |
| Grafana | 3000 | `grafana:3000` |
| TimescaleDB | 5432 | `timescaledb:5432` |
| HiveMQ MQTT | 1883 | `hivemq:1883` |
| Node-RED | 1880 | `nodered:1880` |
| Portainer | 9000 | `portainer:9000` |
| NGINX | 80/443 | `nginx:80` |

## Database

Database: `umh` | Schema in `configs/timescaledb-init/`

| Table | Type | Purpose |
|-------|------|---------|
| `asset` | table | Equipment metadata (ISA-95 hierarchy) |
| `tag` | hypertable | Numeric time-series (compressed after 7 days) |
| `tag_string` | hypertable | Text time-series |

Users: `postgres` (superuser), `kafkatopostgresqlv2` (writer), `grafanareader` (read-only)

## UMH Core Concepts

**Data Contracts:**
- `_raw` -- No validation, simple key-value (default)
- `_<model>_<version>` -- Typed/validated (e.g., `_energy-monitor_v1`)

**Topic structure:** `umh.v1.<enterprise>.<site>.<area>.<line>.<workcell>.<origin_id>.<contract>.<tag>`

**Configuration:**
- `dataFlow:` -- Standalone processing pipelines
- `protocolConverter:` -- Template-based bridges with `{{ .Variables }}`
- Use `uns:` input/output (not `kafka:`)

## Key Conventions

- `max_in_flight: 20` for database flows (matches PgBouncer pool), `64` for historian
- Always add `?sslmode=disable` to PostgreSQL DSN strings in Docker
- `${DB_DSN}` env var for database connections in dataflows
- Never commit `.env` (contains AUTH_TOKEN and credentials)

## Environment Variables

Required in `.env`: `AUTH_TOKEN`, `POSTGRES_PASSWORD`, `HISTORIAN_WRITER_PASSWORD`, `HISTORIAN_READER_PASSWORD`, `GF_ADMIN_PASSWORD`

## Resources

- [UMH Docs](https://docs.umh.app/) | [Management Console](https://management.umh.app/) | [Config Reference](https://docs.umh.app/reference/configuration-reference)
- [Benthos/Redpanda Connect](https://docs.redpanda.com/redpanda-connect/) | [Bloblang Reference](https://docs.redpanda.com/redpanda-connect/guides/bloblang/about/)
