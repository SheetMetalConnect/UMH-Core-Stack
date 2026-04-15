# Historian (TimescaleDB + PgBouncer + Grafana)

Time-series storage with TimescaleDB, connection pooling via PgBouncer, and Grafana for visualization. All included in the main `docker-compose.yaml`.

## Enable the Historian Flow

UMH Core does **not** auto-write to TimescaleDB. Deploy the flow:

1. **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Paste `examples/databridges/flows/historian.yaml`

The flow subscribes to all `_raw` topics and writes to `tag` (numeric) or `tag_string` (text) hypertables via `get_asset_id()`.

## Database

| | |
|---|---|
| Container | `timescaledb` |
| Pool | `pgbouncer` |
| Database | `umh` |
| Init scripts | `configs/timescaledb-init/` |

**Users**: `postgres` (superuser), `kafkatopostgresqlv2` (write), `grafanareader` (read)

**Tables**: `asset`, `tag` (hypertable), `tag_string` (hypertable)

Set credentials in `.env` before first boot — init scripts run once.

## Verify

```bash
docker exec timescaledb psql -U postgres -d umh -c "\dt"
docker exec timescaledb psql -U postgres -d umh -c "\du"
```

## Sizing

| Deployment | Tags | TS_TUNE_MEMORY | TS_TUNE_NUM_CPUS |
|------------|------|----------------|------------------|
| Small | <100 | 4GB | 2 |
| Medium | 100-1000 | 8GB | 4 |
| Large | >1000 | 16GB | 8 |

## Backup

```bash
docker exec timescaledb pg_dump -U postgres umh | gzip > backup-$(date +%Y%m%d).sql.gz
```

## See Also

- [Data Modeling](data-modeling.md) — `_raw` vs data contracts
- [Deployment Lessons](deployment-lessons.md) — DSN config, permissions, PG migration
- [Networking](networking.md) — Database access architecture
- [Integration Patterns](integration-patterns.md) — ERP data persistence
