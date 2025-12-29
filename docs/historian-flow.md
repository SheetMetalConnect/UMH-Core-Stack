# Historian Flow Configuration

Ready-to-paste data flow for writing MQTT data to TimescaleDB.

## Background

In UMH Classic (Kubernetes), the `kafka_to_postgresql_historian_bridge` ran automatically. With UMH Core, you add it via the Management Console.

This flow is adapted from the [UMH Classic historian bridge](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml) — the same Benthos logic that powered the original Kafka-to-TimescaleDB pipeline.

> See also: [UMH Docker Compose documentation](https://github.com/united-manufacturing-hub/united-manufacturing-hub/pull/2352) for the official setup guide.

For database schema and setup, see [Historian Addon](historian.md).

## Setup

1. Open **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Switch to **Advanced Mode**
3. Paste the sections below

> Default password is `umhcore`. Change in production.

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
                    dsn: postgres://kafkatopostgresqlv2:umhcore@pgbouncer:5432/umh_v2?sslmode=disable
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
            dsn: postgres://kafkatopostgresqlv2:umhcore@pgbouncer:5432/umh_v2?sslmode=disable
            table: tag
            columns: [time, asset_id, tag_name, value, origin]
            args_mapping: '[ this.timestamp, this.asset_id, this.tag_name, this.value, "mqtt" ]'
            batching:
              period: 5s
              count: 1000
      - output:
          sql_insert:
            driver: postgres
            dsn: postgres://kafkatopostgresqlv2:umhcore@pgbouncer:5432/umh_v2?sslmode=disable
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

- Default password is `umhcore` - change in production
- PgBouncer (`pgbouncer:5432`) is the database endpoint
- Numeric values go to `tag` table, strings go to `tag_string`

## See Also

- [Historian](historian.md) - Database infrastructure and schema
- [UMH Classic Bridge Source](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/deployment/united-manufacturing-hub/templates/bridges/kafka_to_postgres/historian/configmap.yaml) - Original Benthos config
- [UMH Standalone Flows Docs](https://github.com/united-manufacturing-hub/united-manufacturing-hub/blob/main/umh-core/docs/usage/data-flows/stand-alone-flow.md) - Official standalone flow guide
- [Integrations](integrations.md) - Bridge configuration
