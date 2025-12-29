# Historian Addon (TimescaleDB + PgBouncer + Grafana)

The historian addon provides **time-series storage** with TimescaleDB, connection pooling via PgBouncer, and Grafana for visualization. This stack includes a **pre-built historian bridge** adapted from [UMH Classic](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml).

## Enable the Addon

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

## Enable the Historian Bridge

Add the bridge via Management Console:

1. Open **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Paste the config from [Historian Flow](historian-flow.md)

Works out of the box with default password (`umhcore` - change in production). The bridge subscribes to `umh/#` on HiveMQ and writes to TimescaleDB via PgBouncer.

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

## How the Bridge Works

The pre-built historian bridge (in `configs/config.yaml.example`) does the following:

1. **Subscribes** to `umh/#` on HiveMQ
2. **Parses** topic structure: `umh/v1/<location>/<asset>/<tag>`
3. **Extracts** value and timestamp from JSON payload
4. **Resolves** asset IDs (cached to minimize DB queries)
5. **Inserts** into `tag` (numeric) or `tag_string` (other) hypertables

This is the same logic as the [UMH Classic kafka_to_postgresql_historian_bridge](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml), adapted for MQTT input.

For customization details, see [Historian Flow](historian-flow.md).

## See Also

- [Historian Flow](historian-flow.md) - Complete MQTT to TimescaleDB config
- [Networking](networking.md) - Database access and PgBouncer
- [Operations](operations.md) - Quick start and commands
- [Integrations](integrations.md) - Bridge configuration
