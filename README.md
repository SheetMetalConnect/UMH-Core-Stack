# UMH Core Stack

Turn-key Docker Compose deployment for [United Manufacturing Hub](https://github.com/united-manufacturing-hub/united-manufacturing-hub) — the Swiss Army knife for manufacturing data infrastructure.

**Batteries included:** MQTT, TimescaleDB, Grafana, Node-RED, data flows, and ERP integration patterns.

## What This Provides

**Infrastructure** (docker-compose):
- HiveMQ CE — MQTT broker
- TimescaleDB — Time-series database with pre-configured schema
- Grafana — Dashboards with datasource auto-provisioned
- PgBouncer — Connection pooling
- Node-RED — Flow programming (Projects + Multiplayer enabled)
- Portainer — Container management
- NGINX — Reverse proxy for webhooks

**Data flows** ([examples/databridges](examples/databridges)):
- Historian — UNS → TimescaleDB persistence
- ERP integration — Sales orders with deduplication + history tracking
- MQTT bridges — External system integration and feedback

**Optional addons:**
- [Historian](examples/historian) — TimescaleDB + Grafana + PgBouncer
- [MCP](examples/mcp) — AI/LLM integration for Node-RED and Grafana

**Architecture:** UMH Core runs separately from the stack for reliability and independent updates.

## Quick Start

**Fast client deployment** → [**Quick Start Guide**](docs/quick-start.md)

```bash
# One command: Full stack with AI integration
docker compose -f docker-compose.yaml \
  -f examples/historian/docker-compose.historian.yaml \
  -f examples/mcp/docker-compose.mcp.yaml up -d

# Connect UMH Core + verify deployment
# See quick-start.md for complete 5-minute workflow
```

## Access Services

| Service | URL | Credentials |
|---------|-----|-------------|
| Grafana | http://localhost:3000 | admin / umhcore |
| Node-RED | http://localhost:1880 | — |
| Portainer | http://localhost:9000 | Create on first visit |
| MQTT | localhost:1883 | — |
| MQTT WebSocket | localhost:8083 | — |
| PostgreSQL (via PgBouncer) | localhost:5432 | postgres / umhcore |
| NGINX (webhooks) | http://localhost:8081 | — |

⚠️ **Security:** Change default password `umhcore` before production use.

## Architecture

```
External Systems
      │
      ▼ MQTT (1883) / HTTP (8081)
┌─────────────┐     ┌──────────────┐
│  HiveMQ CE  │────▶│   UMH Core   │
│   + NGINX   │     │  (separate)  │
└─────────────┘     └──────┬───────┘
                           │ UNS (Kafka)
                           ▼
                    ┌──────────────┐
                    │  Data Flows  │
                    └──────┬───────┘
                           │
              ┌────────────┼────────────┐
              ▼            ▼            ▼
        ┌──────────┐ ┌──────────┐ ┌──────────┐
        │Historian │ │   ERP    │ │ Feedback │
        │  Flow    │ │  Flows   │ │  Flow    │
        └────┬─────┘ └────┬─────┘ └────┬─────┘
             │            │            │
             ▼            ▼            ▼
        ┌─────────────────────┐   ┌──────────┐
        │    TimescaleDB      │   │   MQTT   │
        │  tag / erp_* tables │   │ feedback │
        └──────────┬──────────┘   └──────────┘
                   │
                   ▼
              ┌─────────┐
              │ Grafana │
              └─────────┘
```

## Addons

### Historian (TimescaleDB + Grafana)

Time-series storage and visualization. **Recommended for production.**

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

[Full documentation →](examples/historian)

### MCP (AI/LLM Integration)

AI assistant access to Node-RED flows and Grafana dashboards.

```bash
docker compose -f docker-compose.yaml \
  -f examples/historian/docker-compose.historian.yaml \
  -f examples/mcp/docker-compose.mcp.yaml up -d
```

[Full documentation →](examples/mcp)

## Data Patterns

### Historian

Time-series data flows directly from UNS to TimescaleDB hypertables (`tag`, `tag_string`).

### ERP Integration (Pattern C)

Local cache with change detection and full history tracking:

1. External system publishes to `_sales_order.process`
2. Process flow compares against database (deduplication)
3. Republishes as `.create`, `.update`, or `.duplicate`
4. Persistence flow upserts current state + appends to history
5. Feedback flow notifies external systems via MQTT

**Why Pattern C?** Enables event-driven architecture with complete audit trail for process mining.

See [docs/integration-patterns.md](docs/integration-patterns.md) for all patterns.

## Repository Structure

```
.
├── README.md                    # You are here
├── PROJECT.md                   # Architecture and design decisions
├── CLAUDE.md                    # Agent/AI assistant instructions
├── docker-compose.yaml          # Core infrastructure
├── .env.example                 # Environment template
├── configs/                     # Service configurations
│   ├── nginx.conf
│   ├── nodered/settings.js
│   ├── grafana/provisioning/
│   └── timescaledb-init/
├── examples/
│   ├── databridges/             # Data flows + SQL schemas
│   │   ├── flows/               # Deploy these via Management Console
│   │   ├── sql/                 # Database initialization
│   │   └── classic/             # Reference: k8s format
│   ├── historian/               # TimescaleDB addon
│   └── mcp/                     # AI/LLM integration addon
└── docs/                        # Extended documentation
    ├── integration-patterns.md  # Pattern A/B/C explained
    ├── historian.md             # TimescaleDB setup details
    ├── networking.md            # Ports and connectivity
    ├── operations.md            # Common tasks
    ├── security.md              # Production hardening
    ├── troubleshooting.md       # Common issues
    └── ...
```

## Documentation

**Setup & Operations:**
- [Quick Start](docs/quick-start.md) — 5-minute deployment with AI integration
- [Networking](docs/networking.md) — Ports, DNS, and connectivity
- [Operations](docs/operations.md) — Common tasks and workflows
- [Updating](docs/updating.md) — Update procedures

**Integration & Development:**
- [Integration Patterns](docs/integration-patterns.md) — Pattern A/B/C detailed
- [Historian](docs/historian.md) — TimescaleDB deep dive
- [Integrations](docs/integrations.md) — External system integration
- [Migration](docs/migration.md) — Migrating from UMH Classic

**Production & Security:**
- [Security](docs/security.md) — Production hardening checklist
- [Troubleshooting](docs/troubleshooting.md) — Common issues and fixes
- [Extensions](docs/extensions.md) — Optional MES tools (NocoDB, Appsmith, n8n)

## Production Checklist

- [ ] Change default password `umhcore` everywhere:
  ```bash
  grep -r "umhcore" . --include="*.yaml" --include="*.example" --include="*.md"
  ```
- [ ] Set `AUTH_TOKEN` from Management Console
- [ ] Configure TLS/SSL for external endpoints
- [ ] Restrict NGINX CORS headers (currently allows `*`)
- [ ] Set up database backups
- [ ] Configure resource limits in compose files
- [ ] Review [docs/security.md](docs/security.md) for complete hardening

## Contributing

This is a community-driven deployment package for United Manufacturing Hub. Contributions welcome!

**Before submitting:**
- Test with fresh `.env` from `.env.example`
- Verify all services start: `docker compose ps`
- Run validation: `docker compose config`
- Update relevant documentation

## Related Resources

- [UMH Documentation](https://docs.umh.app/)
- [Management Console](https://management.umh.app/)
- [UMH Core Repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub)
- [PROJECT.md](PROJECT.md) — Deep dive on architecture
