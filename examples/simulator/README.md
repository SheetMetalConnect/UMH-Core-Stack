# MetalFab UNS Simulator

22 simulated machines across 3 EU sites publishing to the UNS via MQTT. Publishes `_raw` and `_energy-monitor_v1` data contracts.

## Quick Start

```bash
# From repo root
docker compose -f docker-compose.yaml -f examples/simulator/docker-compose.simulator.yaml up -d
```

## Deploy Flows

Deploy via **Management Console → Data Flows → Stand-alone → Add**:

| # | Flow | Purpose |
|---|------|---------|
| 1 | `flows/simulator_to_uns_bridge.yaml` | Bridges simulator data into UNS (required) |
| 2 | `examples/databridges/flows/historian.yaml` | `_raw` → TimescaleDB |
| 3 | `flows/energy_historian.yaml` | `_energy-monitor_v1` → TimescaleDB (optional) |

Without step 1, data stays on HiveMQ and never reaches UMH Core.

## What Gets Persisted

| Topic | Persisted by | Content |
|-------|-------------|---------|
| `.../{machine}/_raw/{tag}` | historian.yaml | Sensor readings, OEE, counters |
| `.../energy/main/_raw/{tag}` | historian.yaml | Energy consumption/generation |
| `.../energy/main/_energy-monitor_v1/{tag}` | energy_historian.yaml | Energy (validated contract) |
| `.../{machine}/Edge/*`, `Line/*`, `Dashboard/*` | (not persisted) | MQTT dashboards only |

## Complexity Levels

| Level | Name | Default |
|-------|------|---------|
| 1 | Sensors | `_raw` sensor data + energy |
| 2 | Stateful | + Edge/, Line/, state, jobs, OEE **(default)** |
| 3 | ERP/MES | + ERP/, MES/, Dashboard/ |
| 4 | Full | + events, alarms, DPP |

## Source

[github.com/SheetMetalConnect/metalfab-uns-simulator](https://github.com/SheetMetalConnect/metalfab-uns-simulator)
