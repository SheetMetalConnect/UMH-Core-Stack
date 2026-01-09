# Networking

This document describes the internal and external networking architecture of the UMH stack, including Docker networks, port mappings, service discovery, and access patterns.

## Network Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│ External Network (LAN / localhost)                                          │
│                                                                             │
│  Host IP:8081  ──► NGINX ──► umh-core:8040 (Webhook Gateway)               │
│  Host IP:1883  ──► HiveMQ (MQTT Broker)                                    │
│  Host IP:8083  ──► HiveMQ (MQTT WebSocket)                                 │
│  Host IP:1880  ──► Node-RED (Flow Editor)                                  │
│  Host IP:9000  ──► Portainer (Container Management)                        │
│  Host IP:3000  ──► Grafana (Dashboards)                                    │
│  Host IP:5432  ──► PgBouncer (Database Pool)                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              ↓ Docker Port Mapping
┌─────────────────────────────────────────────────────────────────────────────┐
│ umh-network (Docker Bridge)                                                 │
│                                                                             │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐  ┌───────────┐               │
│  │ umh-core  │  │  nginx    │  │  hivemq   │  │  nodered  │               │
│  │ :8040     │  │  :8080    │  │  :1883    │  │  :1880    │               │
│  │ :8051     │  │           │  │  :8000    │  │           │               │
│  └───────────┘  └───────────┘  └───────────┘  └───────────┘               │
│                                                                             │
│  ┌───────────┐  ┌───────────┐  ┌───────────┐                               │
│  │ portainer │  │  grafana  │  │ pgbouncer │◄── Bridge to DB network      │
│  │ :9000     │  │  :3000    │  │ :5432     │                               │
│  └───────────┘  └───────────┘  └───────────┘                               │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
                              ↓ PgBouncer Bridge
┌─────────────────────────────────────────────────────────────────────────────┐
│ timescaledb-network (Docker Internal - Isolated)                            │
│                                                                             │
│  ┌───────────────┐                                                         │
│  │  timescaledb  │  ← Not accessible from umh-network or host directly     │
│  │  :5432        │                                                         │
│  └───────────────┘                                                         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Docker Networks

The stack uses two Docker networks for security isolation. UMH Core is run as a separate container and must be attached to the application network so NGINX, HiveMQ, and PgBouncer can reach it.

### umh-network (Bridge)

The primary network connecting all services that need to communicate with each other.

| Service | Connected | Purpose |
|---------|-----------|---------|
| nginx | Yes | Reverse proxy for webhook endpoints |
| hivemq | Yes | MQTT broker |
| nodered | Yes | Flow-based automation |
| portainer | Yes | Container management UI |
| grafana | Yes | Visualization dashboards |
| pgbouncer | Yes | Database connection pooler (bridges to timescaledb-network) |
| umh-core (external container) | Attach manually | Edge gateway with embedded Kafka (Redpanda) |

### timescaledb-network (Internal)

An isolated network for the database. The `internal: true` flag means containers on this network cannot reach the internet or host network directly.

| Service | Connected | Purpose |
|---------|-----------|---------|
| timescaledb | Yes | Time-series database (only service on this network) |
| pgbouncer | Yes | Acts as the bridge/gateway to the database |

**Why this isolation?**
- Prevents direct database access bypassing connection pooling
- Adds security layer - database only reachable via PgBouncer
- Follows principle of least privilege

## Port Mappings

### External Ports (Host Accessible)

These ports are published to the host and accessible from LAN:

| Service | Container Port | Host Port | Environment Variable | Default |
|---------|---------------|-----------|---------------------|---------|
| NGINX (Webhooks) | 8080 | `PORT_NGINX` | `PORT_NGINX` | 8081 |
| HiveMQ MQTT | 1883 | `PORT_MQTT` | `PORT_MQTT` | 1883 |
| HiveMQ WebSocket | 8000 | `PORT_MQTT_WS` | `PORT_MQTT_WS` | 8083 |
| Node-RED | 1880 | `PORT_NODERED` | `PORT_NODERED` | 1880 |
| Portainer | 9000 | `PORT_PORTAINER` | `PORT_PORTAINER` | 9000 |
| Portainer Edge | 9443 | `PORT_PORTAINER_EDGE` | `PORT_PORTAINER_EDGE` | 9443 |
| Grafana | 3000 | 3000 | (fixed) | 3000 |
| PgBouncer | 5432 | 5432 | (fixed) | 5432 |
| UMH Core (external container) | 8040, 8051 | not published | n/a | internal only |

### Internal Ports (Not Exposed)

These ports are only accessible within the Docker network:

| Service | Internal Port | Purpose |
|---------|--------------|---------|
| umh-core (external container) | 8040 | HTTP/Webhook input (proxied via NGINX) |
| umh-core (external container) | 8051 | Management/GraphQL endpoints |
| timescaledb | 5432 | PostgreSQL (only via PgBouncer) |

### Running UMH Core separately (attach to network)

Launch UMH Core outside the compose stack and attach it to the app network so NGINX/HiveMQ/PgBouncer can reach it:

```bash
docker run -d --restart unless-stopped --name umh-core \
  --network lve-umh-core_umh-network \
  -v umh-core-data:/data \
  -e AUTH_TOKEN=${AUTH_TOKEN} \
  -e RELEASE_CHANNEL=${RELEASE_CHANNEL:-stable} \
  -e API_URL=${API_URL:-https://management.umh.app/api} \
  -e LOCATION_0=${LOCATION_0:-enterprise} \
  management.umh.app/oci/united-manufacturing-hub/umh-core:${UMH_VERSION:-latest}
```

If UMH Core is already running, attach it:

```bash
docker network connect lve-umh-core_umh-network umh-core
```

## Service Discovery (Internal DNS)

Docker provides automatic DNS resolution for service names within the same network. Services communicate using container names as hostnames:

### Internal Connection Strings

| From | To | Connection String |
|------|-----|------------------|
| Any service | HiveMQ MQTT | `mqtt://hivemq:1883` |
| Any service | HiveMQ WebSocket | `ws://hivemq:8000/mqtt` |
| NGINX | UMH Core | `http://umh-core:8040` |
| Grafana | Database | `pgbouncer:5432` |
| PgBouncer | Database | `timescaledb:5432` |
| Node-RED | MQTT | `hivemq:1883` |

### Example: Node-RED MQTT Configuration

When configuring MQTT nodes in Node-RED, use the internal Docker DNS name:

```
Server: hivemq
Port: 1883
```

Do NOT use `localhost` or the host IP from within containers.

## External Access (LAN)

All services are reachable from the LAN via the host's IP and published ports:

| Service | URL Pattern | Example |
|---------|-------------|---------|
| Node-RED | `http://<host-ip>:1880` | `http://192.168.1.100:1880` |
| Grafana | `http://<host-ip>:3000` | `http://192.168.1.100:3000` |
| Portainer | `http://<host-ip>:9000` | `http://192.168.1.100:9000` |
| MQTT Broker | `mqtt://<host-ip>:1883` | `mqtt://192.168.1.100:1883` |
| MQTT WebSocket | `ws://<host-ip>:8083/mqtt` | `ws://192.168.1.100:8083/mqtt` |
| Webhook Endpoint | `http://<host-ip>:8081` | `http://192.168.1.100:8081` |
| Database (via PgBouncer) | `postgresql://<host-ip>:5432` | `postgresql://192.168.1.100:5432/umh_v2` |

### Finding Your Host IP

```bash
# macOS
ipconfig getifaddr en0

# Linux
hostname -I | awk '{print $1}'

# Windows
ipconfig | findstr /i "IPv4"
```

## NGINX Reverse Proxy

NGINX acts as the gateway for webhook/HTTP traffic into UMH Core.

### Why NGINX?

1. **Port Isolation**: UMH Core ports (8040, 8051) are not directly exposed
2. **Security Headers**: Adds X-Frame-Options, XSS protection, etc.
3. **CORS Handling**: Manages cross-origin requests for web clients
4. **Request Logging**: Separate webhook access logs for monitoring
5. **Industry Pattern**: Follows Siemens Industrial Edge, Azure IoT Edge patterns

### Request Flow

```
External Request                    Internal Processing
─────────────────                   ───────────────────
POST http://<host>:8081/webhook/... 
        ↓
    NGINX:8080 (container)
        ↓ proxy_pass
    umh-core:8040
        ↓
    Unified Namespace (Redpanda/Kafka)
```

### NGINX Configuration Highlights

```nginx
upstream umh_webhook {
    server umh-core:8040;  # Docker DNS resolution
}

server {
    listen 8080;
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN";
    add_header X-Content-Type-Options "nosniff";
    add_header X-XSS-Protection "1; mode=block";
    
    # CORS (restrict in production)
    add_header Access-Control-Allow-Origin "*";
    
    location /webhook/ {
        proxy_pass http://umh_webhook/webhook/;
    }
}
```

## MQTT Architecture

### External vs Internal Access

**External (from LAN devices):**
```bash
# Publish from a device on the network
mosquitto_pub -h <host-ip> -p 1883 -t "factory/line1/sensor" -m '{"temp": 42}'
```

**Internal (from containers):**
```bash
# Inside Node-RED or other containers
Server: hivemq
Port: 1883
```

### Data Flow: Device → UMH Core

```
1. Device publishes to HiveMQ
   mqtt://<host-ip>:1883/my/sensor/topic → {"value": 42}

2. UMH Core subscribes via Bridge (configured in Management Console)
   Bridge subscribes to: hivemq:1883

3. Data enters Unified Namespace
   Topic: umh.v1.<LOCATION_0>.<LOCATION_1>.<LOCATION_2>/...
   Example: umh.v1.Sittard/my/sensor/topic
```

## Database Access Architecture

TimescaleDB is completely isolated on its own network. All access goes through PgBouncer.

### Connection Flow

```
External SQL Client (DBeaver, psql, etc.)
        ↓
    <host-ip>:5432
        ↓
    PgBouncer:5432 (connection pooling)
        ↓
    timescaledb:5432 (internal network)
```

### Database Users

| User | Purpose | Permissions |
|------|---------|-------------|
| `postgres` | Superuser | Full access |
| `kafkatopostgresqlv2` | Data writer (UMH Core) | SELECT, INSERT on asset, tag, tag_string |
| `grafanareader` | Dashboard queries | SELECT only on asset, tag, tag_string |

### Connection Examples

**From Grafana (internal):**
```yaml
host: pgbouncer
port: 5432
database: umh_v2
user: grafanareader
```

**From external SQL client:**
```bash
psql -h <host-ip> -p 5432 -U grafanareader -d umh_v2
```

## Portainer Container Management

Portainer provides a web UI for managing Docker containers, networks, and volumes.

### Access

- **URL**: `http://<host-ip>:9000`
- **Edge Agent**: `https://<host-ip>:9443` (for remote management)

### Capabilities

From Portainer you can:
- View all running containers and their status
- Access container logs and console
- Inspect networks (umh-network, timescaledb-network)
- Manage volumes (hivemq-data, nodered-data, etc.)
- Start/stop/restart containers
- View resource usage (CPU, memory)

### Network Inspection

In Portainer, navigate to **Networks** to see:
- `deployment_umh-network`: Main service network
- `deployment_timescaledb-network`: Isolated database network

You can inspect which containers are connected to each network.

## Health Checks

Services have built-in health checks that Docker monitors:

| Service | Health Check | Interval |
|---------|-------------|----------|
| HiveMQ | TCP check on ports 1883 and 8000 | 30s |
| TimescaleDB | `pg_isready -U postgres -d umh_v2` | 10s |
| Grafana | HTTP GET `/api/health` | 30s |
| Node-RED | HTTP GET `/` | 30s |
| PgBouncer | `pg_isready` | 10s |

### Service Dependencies

```
timescaledb (healthy)
     ↓
pgbouncer (healthy)
     ↓
grafana

umh-core (running)
     ↓
nginx
```

## Customizing Ports

All ports can be customized in `.env`:

```bash
# Port Configuration
PORT_NGINX=8081           # Webhook gateway
PORT_MQTT=1883            # MQTT broker
PORT_MQTT_WS=8083         # MQTT WebSocket
PORT_NODERED=1880         # Node-RED UI
PORT_PORTAINER=9000       # Portainer UI
PORT_PORTAINER_EDGE=9443  # Portainer Edge agent
```

After changing ports, restart the stack:

```bash
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml down
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
```

## Security Considerations

### Network Isolation
- TimescaleDB is on an internal network, inaccessible except via PgBouncer
- UMH Core internal ports are hidden behind NGINX

### Production Recommendations
1. **Restrict CORS**: Change `Access-Control-Allow-Origin: *` to specific domains
2. **Enable MQTT Auth**: Set `HIVEMQ_ALLOW_ALL_CLIENTS=false` and configure authentication
3. **Change Default Passwords**: Update all passwords in `.env` before deployment
4. **Use TLS**: Configure HTTPS for NGINX and TLS for MQTT
5. **Firewall Rules**: Only expose necessary ports to the network

### Default Credentials (Change These!)

| Service | Username | Password |
|---------|----------|----------|
| Grafana | admin | umhcore |
| PostgreSQL | postgres | umhcore |
| PgBouncer writer | kafkatopostgresqlv2 | umhcore |
| PgBouncer reader | grafanareader | umhcore |

## Troubleshooting

### Container Can't Reach Another Service

1. Check both containers are on the same network:
   ```bash
   docker network inspect deployment_umh-network
   ```

2. Verify DNS resolution works:
   ```bash
   docker exec nodered ping hivemq
   ```

### Port Already in Use

```bash
# Find what's using the port
lsof -i :1883

# Change the port in .env and restart
```

### Database Connection Refused

1. Check PgBouncer is healthy:
   ```bash
   docker exec pgbouncer pg_isready -h localhost
   ```

2. Verify TimescaleDB is running:
   ```bash
   docker logs timescaledb --tail 20
   ```

### NGINX Returns 502 Bad Gateway

UMH Core might not be ready. Check its logs:
```bash
docker logs umh-core --tail 50
```

## See Also

- [Overview](overview.md) - Architecture and data flow
- [Operations](operations.md) - Quick start and commands
- [Integrations](integrations.md) - Bridge and Node-RED configuration
- [Security](security.md) - Production hardening
