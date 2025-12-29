# Historian Flow Configuration

This document provides a ready-to-paste data flow for storing MQTT data in TimescaleDB.

For full historian setup including database schema, Grafana queries, and maintenance, see [Historian Addon README](../examples/historian/README.md).

## Quick Setup

1. Open **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Switch to **Advanced Mode**
3. Paste the sections below

## Input

```yaml
input:
  mqtt:
    urls:
      - tcp://hivemq:1883
    topics:
      - umh/#
    client_id: umh-historian
    clean_session: true
```

## Pipeline

```yaml
pipeline:
  processors:
    - bloblang: |
        let topic = meta("mqtt_topic").or(meta("topic")).or("")
        let parts = $topic.split("/")
        let start = if $parts.length() > 1 && $parts.index(0) == "umh" && $parts.index(1) == "v1" {
          2
        } else if $parts.length() > 0 && $parts.index(0) == "umh" {
          1
        } else {
          0
        }

        let has_min = $parts.length() > ($start + 1)
        let tag = if $has_min { $parts.index(-1) } else { "" }
        let asset = if $has_min { $parts.index(-2) } else { "" }
        let location = if $parts.length() > ($start + 2) { $parts.slice($start, -2).join(".") } else { "" }

        let raw = content()
        let parsed = $raw.parse_json().catch($raw)
        let value = if $parsed.type() == "object" && $parsed.has("value") { $parsed.value } else { $parsed }
        let timestamp = if $parsed.type() == "object" && $parsed.has("timestamp_ms") {
          ($parsed.timestamp_ms / 1000).ts_format()
        } else if $parsed.type() == "object" && $parsed.has("timestamp") {
          $parsed.timestamp
        } else {
          now().ts_format()
        }

        root = {
          "asset_name": $asset,
          "location": $location,
          "tag_name": $tag,
          "value": $value,
          "timestamp": $timestamp
        }

        root = if root.asset_name == "" || root.tag_name == "" { deleted() } else { root }

    - label: get_asset_id
      branch:
        processors:
          - cached:
              key: '${! this.location + "|" + this.asset_name }'
              cache: id_cache
              processors:
                - sql_raw:
                    driver: postgres
                    dsn: postgres://kafkatopostgresqlv2:changeme@pgbouncer:5432/umh_v2?sslmode=disable
                    query: |
                      INSERT INTO asset (asset_name, location)
                      VALUES ($1, $2)
                      ON CONFLICT (asset_name) DO UPDATE SET location = EXCLUDED.location
                      RETURNING id;
                    args_mapping: '[ this.asset_name, this.location ]'
                - bloblang: |
                    root = if this.length() > 0 { this.index(0).get("id") } else { null }
      result_map: 'root.asset_id = this'

    - switch:
        - check: this.asset_id == null
          processors:
            - bloblang: |
                root = deleted()
```

## Output

```yaml
output:
  switch:
    cases:
      - check: this.value.type() == "number"
        output:
          sql_insert:
            driver: postgres
            dsn: postgres://kafkatopostgresqlv2:changeme@pgbouncer:5432/umh_v2?sslmode=disable
            table: tag
            columns: [time, asset_id, tag_name, value, origin]
            args_mapping: '[ this.timestamp, this.asset_id, this.tag_name, this.value, "mqtt" ]'
            batching:
              period: 5s
              count: 1000
      - output:
          sql_insert:
            driver: postgres
            dsn: postgres://kafkatopostgresqlv2:changeme@pgbouncer:5432/umh_v2?sslmode=disable
            table: tag_string
            columns: [time, asset_id, tag_name, value, origin]
            args_mapping: '[ this.timestamp, this.asset_id, this.tag_name, this.value, "mqtt" ]'
            batching:
              period: 5s
              count: 1000
```

## YAML Inject (Cache)

```yaml
cache_resources:
  - label: id_cache
    memory:
      default_ttl: 24h
```

## Expected Topic Structure

```
umh/v1/<location>/<asset>/<tag>
```

Example: `umh/v1/factory/line1/pump/temperature`
- location: `factory.line1`
- asset: `pump`
- tag: `temperature`

## Notes

- Replace `changeme` with your actual `HISTORIAN_WRITER_PASSWORD` from `.env`
- PgBouncer (`pgbouncer:5432`) is the database endpoint
- Numeric values go to `tag` table, strings go to `tag_string`

## See Also

- [Historian Addon](../examples/historian/README.md) - Full setup guide
- [Historian](historian.md) - Database overview
- [Integrations](integrations.md) - Bridge configuration
