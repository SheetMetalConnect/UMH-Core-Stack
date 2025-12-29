# Overview

## Architecture

```
                                   ┌─────────────────────────────────────┐
                                   │         External Devices            │
                                   │    (PLCs, Sensors, MQTT Clients)    │
                                   └──────────────┬──────────────────────┘
                                                  │ MQTT (1883)
                                                  ▼
┌─────────────────────────────────────────────────────────────────────────────────┐
│                              UMH Network (Docker)                               │
│                                                                                 │
│  ┌──────────────┐     ┌──────────────┐     ┌──────────────┐                      │
│  │   HiveMQ CE  │     │   Node-RED   │     │   Grafana    │                      │
│  │  MQTT Broker │     │  Flow Editor │     │  Dashboards  │                      │
│  │   :1883      │     │   :1880      │     │   :3000      │                      │
│  └──────┬───────┘     └──────────────┘     └──────┬───────┘                      │
│         │ MQTT Subscribe                     ▲          │                        │
│         ▼                                    │          ▼                        │
│  ┌──────────────┐                     ┌──────────────┐                           │
│  │   UMH Core   │────────────────────►│  PgBouncer   │                           │
│  │              │  Historian output    │   :5432      │                           │
│  │ • Bridges    │                      └──────┬───────┘                           │
│  │ • Redpanda   │                             ▼                                  │
│  │ • Agent      │                      ┌──────────────┐                          │
│  └──────┬───────┘                      │ TimescaleDB  │                          │
│         │                              │  PostgreSQL  │                          │
│         │                              │  internal    │                          │
│         │                              └──────────────┘                          │
│         │ Webhook HTTP input (port 8040 inside container)                        │
│         ▼                                                                        │
│  ┌──────────────┐                                                                │
│  │   NGINX      │  Reverse proxy / webhook routing                               │
│  │   :8081      │  (TLS and auth optional)                                       │
│  └──────────────┘                                                                │
│                                                                                 │
│                     ┌──────────────┐                                            │
│                     │  Portainer   │                                            │
│                     │   :9000      │                                            │
│                     └──────────────┘                                            │
└─────────────────────────────────────────────────────────────────────────────────┘
```

## Key Concepts

### UMH Core
- Embedded Redpanda provides Kafka-based Unified Namespace (UNS)
- Bridges connect external protocols (MQTT, OPC-UA, Modbus, S7) to UNS
- Agent manages configuration from Management Console
- Configure via management.umh.app UI or YAML

### MQTT Broker (HiveMQ CE)
- External MQTT broker for device connectivity
- UMH Core bridges subscribe to MQTT topics and publish to UNS
- Devices publish to `hivemq:1883`, data flows into UNS via bridges

### NGINX (Webhooks)
- Reverse proxy for HTTP input data flows in UMH Core
- Exposes `/webhook/...` on `http://localhost:8081`
- Add TLS/auth at NGINX for production

### Historian Addon
- PgBouncer pools connections between UMH Core/Grafana and TimescaleDB
- TimescaleDB stores time-series data from UMH Core data flows
- Grafana provides dashboards and exploration

### Data Flow
1. Devices -> MQTT Broker (HiveMQ CE)
2. UMH Core Bridge subscribes to MQTT topics
3. Bridge transforms and publishes to UNS (Redpanda/Kafka)
4. Data Flows can write to TimescaleDB, external systems, etc.

## Stack Components

| Service | Port | Description |
|---------|------|-------------|
| **UMH Core** | internal | Edge gateway, UNS (Redpanda), Bridges |
| **NGINX** | 8081 | Reverse proxy for webhook HTTP inputs |
| **HiveMQ CE** | 1883, 8083 | MQTT broker for device connectivity |
| **PgBouncer** | 5432 | TimescaleDB connection pooling |
| **TimescaleDB** | internal | Time-series database (historian addon) |
| **Grafana** | 3000 | Visualization dashboards (historian addon) |
| **Node-RED** | 1880 | Flow-based programming for IoT |
| **Portainer** | 9000, 9443 | Docker management UI |

## Networking Notes

- `umh-network` is a user-defined bridge for inter-container DNS and traffic.
- `timescaledb-network` is internal; only PgBouncer can reach TimescaleDB.
- External devices on the LAN access services via the host IP and published ports.

## See Also

- [Operations](operations.md) - Quick start and commands
- [Networking](networking.md) - Detailed port mappings and LAN access
- [Historian](historian.md) - TimescaleDB and Grafana setup
- [Integrations](integrations.md) - Bridge configuration and Node-RED
