# Data Bridges

UMH Core data flows for historian and ERP integration with TimescaleDB.

## Flows

| File | Type | Purpose |
|------|------|---------|
| `historian.yaml` | dataFlow | UNS → TimescaleDB (time-series) |
| `mqtt_to_uns_bridge.yaml` | protocolConverter | MQTT → UNS (ingest) |
| `sales_order_process.yaml` | dataFlow | Deduplication (create/update/duplicate) |
| `sales_order_to_timescale.yaml` | dataFlow | Persist with history tracking |
| `timescale_delete.yaml` | dataFlow | Delete handling |
| `uns_to_mqtt_feedback.yaml` | dataFlow | UNS → MQTT (notifications) |

## Asset Model

All flows use consistent asset mapping:

```
Topic: umh.v1.acme.chicago.packaging.line1._historian.temp
       └─────────────────────────────────┘
                 location path

→ asset_name = 'line1'        (last segment)
→ location   = 'acme.chicago.packaging'  (path above asset)
```

The `get_asset_id()` SQL function produces identical results.

## Deployment

1. **Initialize ERP schema** (after stack is running):
   ```bash
   docker exec -i timescaledb psql -U postgres -d umh_v2 < examples/databridges/sql/02-erp-schema.sql
   ```

2. **Deploy flows** via Management Console:
   - Data Flows → Standalone → Add → Advanced Mode
   - Paste flow content

## Topic Convention

```
umh.v1.{location}._sales_order.process    ← Incoming from ERP
umh.v1.{location}._sales_order.create     ← New record
umh.v1.{location}._sales_order.update     ← Changed
umh.v1.{location}._sales_order.duplicate  ← No change
umh.v1.{location}._sales_order.delete     ← Removal
```

## Connection Defaults

| Service | Internal (Docker) | External (Host) |
|---------|-------------------|-----------------|
| PostgreSQL | `pgbouncer:5432` | `localhost:5432` |
| MQTT | `hivemq:1883` | `localhost:1883` |
| Kafka | `localhost:9092` | `localhost:9092` |

## Structure

```
databridges/
├── flows/          # UMH Core flows (deploy these)
├── sql/            # Database schema
└── classic/        # Reference: original k8s format
```
