# Integrations

## Configuring UMH Core Bridges

### Via Management Console (Recommended)

1. Go to management.umh.app
2. Select your instance
3. Go to Data Flows -> Bridges
4. Click Add Bridge
5. Configure MQTT input pointing to `hivemq:1883`

This stack does not ship preconfigured data flows in `data/config.yaml`.
Create bridges and historian flows in the Management Console.

### Example Bridge Configuration (YAML)

In `/data/config.yaml` on UMH Core:

```yaml
dataFlow:
  - name: mqtt-to-uns
    desiredState: active
    dataFlowComponentConfig:
      benthos:
        input:
          mqtt:
            urls:
              - tcp://hivemq:1883
            topics:
              - sensors/#
            client_id: umh-bridge
        pipeline:
          processors:
            - tag_processor:
                defaults: |
                  msg.meta.location_path = "enterprise.site.area"
                  msg.meta.data_contract = "_raw"
                  msg.meta.tag_name = msg.topic
                  return msg;
        output:
          uns: {}
```

## Connecting Services

### Node-RED to MQTT
- Host: `hivemq`
- Port: `1883`

### External MQTT Devices
- Broker host: `<host-ip>`
- Port: `1883` (or `PORT_MQTT` if overridden)
- WebSocket MQTT: `8083` (or `PORT_MQTT_WS`)

Example:
```bash
mosquitto_pub -h <host-ip> -p 1883 -t my/topic -m '{"value": 42}'
```

### NGINX Webhooks
- Create an HTTP input data flow in Management Console (port 8040 inside UMH Core)
- Call it via `http://localhost:8081/webhook/<your-endpoint>`

### Node-RED to TimescaleDB
- Host: `pgbouncer`
- Port: `5432`
- Database: `umh_v2`
- Users: `kafkatopostgresqlv2` (write) or `grafanareader` (read)

### Node-RED Flow Persistence
This stack uses a named volume (`nodered-data`) to persist flows across restarts. If you prefer a host bind mount, replace the volume with a host path, for example:

```yaml
    volumes:
      - /home/user/node_red_data:/data
```

### Grafana to TimescaleDB
Grafana is auto-provisioned via `configs/grafana/provisioning`.
If you add a datasource manually:
1. Add PostgreSQL data source
2. Host: `pgbouncer:5432`
3. Database: `umh_v2`
4. Enable TimescaleDB option

## See Also

- [Networking](networking.md) - Ports and internal DNS names
- [Historian](historian.md) - Database setup and users
- [Historian Flow](historian-flow.md) - MQTT to TimescaleDB config
- [Operations](operations.md) - Quick start and commands
