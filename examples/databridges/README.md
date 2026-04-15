# Data Bridges

UMH Core data flow templates for historian, protocol bridges, and ERP integration.

## Flow Templates

| File | Purpose |
|------|---------|
| `historian.yaml` | `_raw` sensor data → TimescaleDB (tag/tag_string tables) |
| `mqtt_bridge.yaml` | External MQTT broker → UNS (any broker, any topic pattern) |
| `mqtt_to_uns_bridge.yaml` | ERP entity MQTT topics → UNS (process + delete actions) |
| `uns_to_mqtt_feedback.yaml` | UNS → MQTT feedback (notifications back to ERP) |
| `opcua_bridge.yaml` | OPC-UA server → UNS (subscribe to tags) |
| `tasmota_bridge.yaml` | Tasmota IoT devices → UNS (JSON sensor parsing) |
| `erp_process.yaml` | ERP deduplication template (create/update/duplicate) |
| `erp_to_timescale.yaml` | ERP persistence template (UPSERT + history tracking) |
| `timescale_delete.yaml` | Delete event handling (UNS → TimescaleDB DELETE) |

Simulator-specific flows are in [`examples/simulator/flows/`](../simulator/flows/).

## Deployment

1. **Deploy flows** via Management Console:
   - Data Flows → Standalone → Add → Advanced Mode → paste flow content

2. **For ERP flows**, initialize schema first:
   ```bash
   docker exec -i timescaledb psql -U postgres -d umh < examples/databridges/sql/02-erp-schema.sql
   ```

## Adding a New ERP Entity

Use the ERP templates (`erp_process.yaml` + `erp_to_timescale.yaml`):

1. Copy both templates, replace placeholders (ENTITY_NAME, TABLE_NAME, etc.)
2. Create the database table + history table (see `sql/02-erp-schema.sql` for pattern)
3. Add MQTT topic subscriptions to `mqtt_to_uns_bridge.yaml`
4. Add delete handler case to `timescale_delete.yaml`
5. Deploy both flows

## Topic Convention

```
umh.v1.{location}._entity_name.process    <- Incoming from ERP
umh.v1.{location}._entity_name.create     <- New record (after dedup)
umh.v1.{location}._entity_name.update     <- Changed fields
umh.v1.{location}._entity_name.duplicate  <- No change (dropped)
umh.v1.{location}._entity_name.delete     <- Removal
```

## Asset Model

All flows use ISA-95 asset mapping via `get_asset_id()`:

```
Topic: umh.v1.mycompany.factory1.cutting.laser_01._raw.temperature
       └──────────── location path ──────────────┘└contract┘└─tag─┘
```

## Connection Defaults

| Service | Internal (Docker) | External (Host) |
|---------|-------------------|-----------------|
| PostgreSQL | `timescaledb:5432` | `localhost:5432` |
| MQTT | `hivemq:1883` | `localhost:1883` |
| Kafka | `localhost:9092` | `localhost:9092` |
