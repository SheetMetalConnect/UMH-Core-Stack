# Data Modeling

> **Official docs**: [docs.umh.app/usage/data-modeling](https://docs.umh.app/usage/data-modeling)

## _raw — Start Here

Every UMH deployment starts with `_raw`. No setup, no validation, just flow:

```
Device → Bridge → _raw → UNS → historian flow → TimescaleDB
```

**Topic**: `umh/v1/metalfab/eindhoven/cutting/laser_01/_raw/laser_power`
**Payload**: `85.5` (bare value)

The historian flow catches everything. Most deployments never need more than this.

## Data Contracts — When You Scale

At 5 sites and 200 machines, `_raw` becomes a problem — anyone can publish anything. Data contracts add validation:

```
Device → Bridge → _energy-monitor_v1 → UNS → energy historian → TimescaleDB
                         ↑
                  Rejects bad data here
```

Create a data model in Management Console → Data Models → Add. UMH auto-generates the contract (`_energy-monitor_v1`). See `examples/simulator/flows/energy-monitor.yaml` for a working example.

## Topic Structure

```
umh/v1/metalfab/eindhoven/energy/main/_energy-monitor_v1/consumption_kw
       └──── WHERE ─────────────────┘└──── WHAT ────────┘└── WHICH ──┘
              (location_path)          (data_contract)    (tag_name)
```

## _raw vs Data Contracts

| | `_raw` | Data Contract |
|---|---|---|
| **Setup** | Zero config | Define model in Management Console |
| **Validation** | None | Type-checked at bridge |
| **Best for** | Single site, prototyping | Multi-site, production |
| **Historian** | Generic (one flow catches all) | Per-contract (targeted) |

Start with `_raw`. Add contracts when data quality matters.

## Included Examples

| File | Purpose |
|------|---------|
| `examples/databridges/flows/historian.yaml` | `_raw` → TimescaleDB |
| `examples/simulator/flows/simulator_to_uns_bridge.yaml` | Simulator → UNS bridge |
| `examples/simulator/flows/energy-monitor.yaml` | Energy data model definition |
| `examples/simulator/flows/energy_historian.yaml` | `_energy-monitor_v1` → TimescaleDB |

The [MetalFab simulator](https://github.com/SheetMetalConnect/metalfab-uns-simulator) publishes to both `_raw` and `_energy-monitor_v1` so you can compare side by side.

## See Also

- [Historian](historian.md) — TimescaleDB schema and setup
- [Integration Patterns](integration-patterns.md) — ERP data flows
- [Deployment Lessons](deployment-lessons.md) — Production-tested tips
