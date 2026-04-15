# Troubleshooting

Quick fixes for common issues. For production deployment lessons, see [deployment-lessons.md](deployment-lessons.md).

## Services not starting

```bash
docker compose logs <service-name>
# Or via CLI: umh logs <service> --tail 100
```

## UMH Core keeps restarting

If you see `s6-applyuidgid: fatal: unable to set supplementary group list`,
comment out `user: "1000:1000"` in `docker-compose.yaml` and restart.

## Webhook returns 502

NGINX proxies `/webhook/...` to UMH Core. A 502 is expected until you create
an HTTP input data flow in Management Console that binds to port 8040.

## MQTT connection issues

```bash
docker compose logs hivemq
```

## Database connection issues

```bash
docker compose logs pgbouncer
docker compose logs timescaledb
```

**Common cause:** Missing `?sslmode=disable` in DSN strings. See [deployment-lessons.md](deployment-lessons.md#critical-dsn-configuration).

## Data not appearing in TimescaleDB

1. Check historian flow is deployed and active
2. Check UNS has data: `umh topic ls --filter "_raw"`
3. Check DB connectivity: `umh db query "SELECT 1"`
4. Check flow logs: `umh logs umh --tail 50`

## Memory pressure (Redpanda timeouts after ~30 min)

On 16GB servers, reduce Redpanda memory to 1.5GB and TimescaleDB `shared_buffers` to 2GB. Keep 25%+ RAM free. See [deployment-lessons.md](deployment-lessons.md#critical-max_in_flight-limits).

## See Also

- [Operations](operations.md) — Common commands
- [Networking](networking.md) — Port mappings and health checks
- [Historian](historian.md) — Database configuration
- [Deployment Lessons](deployment-lessons.md) — Production-tested fixes
