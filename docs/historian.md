# Historian Addon (TimescaleDB + PgBouncer + Grafana)

The historian addon is enabled by composing:
```
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

## Database

- Container: `timescaledb`
- Connection pool: `pgbouncer`
- Database: `umh_v2`
- Users:
  - `postgres` (superuser)
  - `kafkatopostgresqlv2` (write)
  - `grafanareader` (read)
- Tables:
  - `asset`
  - `tag`
  - `tag_string`

Initialization scripts live at:
`configs/timescaledb-init`

## Grafana

Grafana is preconfigured via provisioning:
- `GF_ADMIN_USER`
- `GF_ADMIN_PASSWORD`
- datasource points to `pgbouncer:5432`

## Environment Variables

Historian variables are in `.env` (or append from
`examples/historian/.env.historian.example`).

Set credentials before the first boot; the init scripts apply them only on initial database creation.

## Quick Verification

```
# Tables
docker exec timescaledb psql -U postgres -d umh_v2 -c "\\dt"

# Roles
docker exec timescaledb psql -U postgres -d umh_v2 -c "\\du"

# PgBouncer
docker exec pgbouncer pg_isready -h pgbouncer
```

## Historian Data Flow

Use the Management Console to add the MQTT -> TimescaleDB flow. See [Historian Flow](historian-flow.md) for the complete configuration.

## See Also

- [Historian Flow](historian-flow.md) - Complete MQTT to TimescaleDB config
- [Networking](networking.md) - Database access and PgBouncer
- [Operations](operations.md) - Quick start and commands
- [Integrations](integrations.md) - Bridge configuration
