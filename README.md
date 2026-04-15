# UMH Core Starter Kit

[![UMH Core](https://img.shields.io/badge/UMH_Core-latest-blue)](https://docs.umh.app/)
[![TimescaleDB](https://img.shields.io/badge/TimescaleDB-2.24.0--pg17-orange)](https://www.timescale.com/)
[![Grafana](https://img.shields.io/badge/Grafana-12.3.0-E6522C)](https://grafana.com/)
[![HiveMQ CE](https://img.shields.io/badge/HiveMQ_CE-latest-FFC000)](https://www.hivemq.com/community/)
[![Node-RED](https://img.shields.io/badge/Node--RED-latest-8F0000)](https://nodered.org/)
[![Docker Compose](https://img.shields.io/badge/Docker_Compose-v2-2496ED)](https://docs.docker.com/compose/)

Opinionated, batteries-included Docker Compose stack to build your Unified Namespace with [UMH Core](https://docs.umh.app/). One command and you're running.

> **Community starter kit.** For production deployments, enterprise support, and professional services, contact the [UMH team](https://www.umh.app/) directly.
>
> Official docs and configuration reference: [docs.umh.app](https://docs.umh.app/)

## Quick Start

```bash
git clone https://github.com/SheetMetalConnect/UMH-Core-Stack.git
cd UMH-Core-Stack

cp .env.example .env
# Edit .env — paste your AUTH_TOKEN from https://management.umh.app

docker compose up -d
docker compose ps
```

## What's Included

| Service | Port | Purpose |
|---------|------|---------|
| **UMH Core** | (internal) | Industrial data hub with embedded Redpanda |
| **TimescaleDB** | 5432 | Time-series database (PostgreSQL 17) |
| **Grafana** | 3000 | Dashboards and visualization |
| **HiveMQ CE** | 1883 | Local MQTT broker |
| **Node-RED** | 1880 | Flow-based data integration |
| **Portainer** | 9000 | Container management UI |
| **NGINX** | 80/443 | Reverse proxy |

Default credentials are `admin` / `changeme` (Grafana) and `postgres` / `changeme` (TimescaleDB). Change these before production use.

## Deploy the Historian

Data does **not** persist to TimescaleDB automatically. You need a DataFlow:

1. Open [Management Console](https://management.umh.app) -> your instance -> Data Flows -> Stand-alone
2. Click **Add**, paste the contents of `examples/databridges/flows/historian.yaml`
3. Deploy

## Demo Data (Optional)

See data flowing end-to-end with the [MetalFab UNS Simulator](https://github.com/SheetMetalConnect/metalfab-uns-simulator):

```bash
docker compose -f docker-compose.yaml -f examples/simulator/docker-compose.simulator.yaml up -d
```

Simulator -> HiveMQ -> UMH Core -> historian -> TimescaleDB -> Grafana.

## Directory Structure

```
.
├── docker-compose.yaml             # Full stack definition
├── .env.example                    # Environment template (start here)
├── nginx.conf                      # Reverse proxy config
├── configs/
│   ├── nodered/settings.js         # Node-RED settings
│   ├── grafana/provisioning/       # Datasources + starter dashboards
│   └── timescaledb-init/           # Historian schema (runs on first boot)
├── examples/
│   ├── databridges/flows/          # DataFlow templates (historian, ERP, bridges)
│   ├── databridges/sql/            # ERP schema extensions
│   ├── simulator/                  # MetalFab simulator overlay
│   ├── historian/                  # Reference historian overlay
│   └── mcp/                        # Standalone MCP server overlay
└── docs/
    ├── operations.md               # Quick start and common commands
    ├── networking.md               # Network architecture, ports, DNS
    ├── data-modeling.md            # _raw vs data contracts, topic structure
    ├── historian.md                # TimescaleDB setup, backup, sizing
    ├── integration-patterns.md     # ERP integration patterns
    └── troubleshooting.md          # Common issues and fixes
```

## DataFlow Templates

Ready-to-use Benthos dataflows in `examples/databridges/flows/`:

| Template | Purpose |
|----------|---------|
| `historian.yaml` | `_raw` topics -> TimescaleDB |
| `mqtt_bridge.yaml` | External MQTT broker -> UNS |
| `opcua_bridge.yaml` | OPC-UA server -> UNS |
| `tasmota_bridge.yaml` | Tasmota IoT devices -> UNS |
| `erp_process.yaml` | ERP entity deduplication |
| `erp_to_timescale.yaml` | ERP persistence (UPSERT + history) |

See `examples/databridges/README.md` for the full list and usage instructions.

## Production Checklist

- [ ] Replace all `changeme` passwords (`grep -r "changeme" . --include="*.yaml" --include="*.example" --include="*.sh"`)
- [ ] Set `AUTH_TOKEN` from [Management Console](https://management.umh.app)
- [ ] Configure TLS (place certs in `./certs`, uncomment HTTPS block in `nginx.conf`)
- [ ] Restrict NGINX CORS headers (currently allows `*`)
- [ ] Set up database backups
- [ ] Tune `TS_TUNE_MEMORY` and `TS_TUNE_NUM_CPUS` for your hardware

## Documentation

| Guide | What it covers |
|-------|---------------|
| [Operations](docs/operations.md) | Quick start, common commands, updating |
| [Networking](docs/networking.md) | Network architecture, ports, DNS, security |
| [Data Modeling](docs/data-modeling.md) | `_raw` vs data contracts, topic structure |
| [Historian](docs/historian.md) | TimescaleDB schema, sizing, backup |
| [Integration Patterns](docs/integration-patterns.md) | ERP integration patterns |
| [Troubleshooting](docs/troubleshooting.md) | Common issues and quick fixes |

## Resources

- [UMH Documentation](https://docs.umh.app/) -- official guides and config reference
- [Management Console](https://management.umh.app/) -- cloud management for UMH instances
- [UMH Core Repository](https://github.com/united-manufacturing-hub/united-manufacturing-hub) -- open-source platform
- [Benthos/Redpanda Connect](https://docs.redpanda.com/redpanda-connect/) -- dataflow processor docs

## Contributing

Contributions welcome. Before submitting:

- Test with a fresh `.env` from `.env.example`
- Verify: `docker compose up -d && docker compose ps`
- Validate: `docker compose config`

## License

[Apache License 2.0](LICENSE)

This is a community deployment template supporting the [UMH mission](https://docs.umh.app/) of making industrial data accessible. It does not modify or redistribute UMH source code.

### Third-party components

| Component | License | Source |
|-----------|---------|--------|
| [UMH Core](https://github.com/united-manufacturing-hub/united-manufacturing-hub) | Apache 2.0 | United Manufacturing Hub GmbH |
| [TimescaleDB](https://github.com/timescale/timescaledb) | Timescale License / Apache 2.0 | Timescale, Inc. |
| [Grafana](https://github.com/grafana/grafana) | AGPL 3.0 | Grafana Labs |
| [HiveMQ CE](https://github.com/hivemq/hivemq-community-edition) | Apache 2.0 | HiveMQ GmbH |
| [Node-RED](https://github.com/node-red/node-red) | Apache 2.0 | OpenJS Foundation |
| [Portainer CE](https://github.com/portainer/portainer) | Zlib | Portainer.io |
| [NGINX](https://github.com/nginx/nginx) | BSD-2 | F5, Inc. |

All trademarks remain property of their respective owners.

---

Built by [Van Enkhuizen Systems](https://vanenkhuizen.com)
