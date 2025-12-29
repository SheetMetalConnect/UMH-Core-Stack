# Troubleshooting

## Services not starting

```bash
docker compose logs <service-name>
```

## UMH Core keeps restarting

If you see `s6-applyuidgid: fatal: unable to set supplementary group list`,
comment out `user: "1000:1000"` in `docker-compose.yaml` and restart:

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d umh-core
```

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

## See Also

- [Operations](operations.md) - Common commands
- [Networking](networking.md) - Port mappings and health checks
- [Historian](historian.md) - Database configuration
