# Quick Start Guide

**5-minute deployment** of UMH Core stack with AI integration for new client sites.

## Prerequisites

- Docker and Docker Compose installed
- Port availability: 1880, 1883, 3000, 3003, 5432, 8081, 8083, 9000
- AUTH_TOKEN from [UMH Management Console](https://management.umh.app/)

## 🚀 Rapid Deployment (5 minutes)

### Step 1: Environment Setup (30 seconds)

```bash
# Clone and configure
git clone <your-umh-repo>
cd LVE-UMH-CORE
cp .env.example .env

# Edit .env: Set AUTH_TOKEN only (required)
# All other defaults work for immediate deployment
```

### Step 2: Deploy Full Stack (2 minutes)

```bash
# Single command: Core + Historian + AI Integration
docker compose -f docker-compose.yaml \
  -f examples/historian/docker-compose.historian.yaml \
  -f examples/mcp/docker-compose.mcp.yaml up -d

# Wait for services to be ready
sleep 30
```

### Step 3: Verify Deployment (1 minute)

```bash
# Check all services are running
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep -E "(umh|postgres|grafana|nodered|hivemq|nginx|portainer)"

# Test key endpoints
curl -s http://localhost:3000/api/health | grep '"commit"'  # Grafana
curl -s http://localhost:1880/ | grep -q "Node-RED"         # Node-RED  
curl -s http://localhost:3003 | grep -q "postgres"          # PostgreSQL MCP
```

### Step 4: Connect UMH Core (1 minute)

```bash
# Get network name (includes directory prefix)
NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep umh-network)
echo "Network: $NETWORK_NAME"

# Run UMH Core
docker run -d --restart unless-stopped --name umh-core \
  --network $NETWORK_NAME \
  -v umh-core-data:/data \
  -e AUTH_TOKEN=$AUTH_TOKEN \
  -e LOCATION_0=client-site \
  management.umh.app/oci/united-manufacturing-hub/umh-core:latest

# Verify UMH Core connected
sleep 10
docker logs umh-core --tail 5
```

### Step 5: AI Setup (30 seconds)

```bash
# Configure AI client with documentation context (one-time setup)
claude mcp add --transport http --scope user gitbook https://docs.umh.app/~gitbook/mcp
claude mcp add --transport http --scope user postgres-docs https://mcp.tigerdata.com/docs  
claude mcp add --transport http --scope user redpanda https://docs.redpanda.com/mcp

# Add live database access (per deployment)
claude mcp add --transport http --scope user umh-postgres http://localhost:3003

# Verify MCP setup
claude mcp list | grep Connected
```

## ✅ Verification & Testing

### Service Accessibility Test

```bash
#!/bin/bash
# Quick service check script

echo "=== UMH Stack Health Check ==="

# Core Services
services=(
  "http://localhost:1880|Node-RED"
  "http://localhost:3000|Grafana"  
  "http://localhost:9000|Portainer"
  "http://localhost:3003|PostgreSQL MCP"
  "tcp://localhost:1883|MQTT Broker"
  "tcp://localhost:5432|PostgreSQL"
)

for service in "${services[@]}"; do
  url=$(echo $service | cut -d'|' -f1)
  name=$(echo $service | cut -d'|' -f2)
  
  if [[ $url == tcp://* ]]; then
    # TCP connection test
    host=$(echo $url | cut -d'/' -f3 | cut -d':' -f1)
    port=$(echo $url | cut -d':' -f3)
    if timeout 3 bash -c "echo >/dev/tcp/$host/$port" 2>/dev/null; then
      echo "✅ $name ($url)"
    else
      echo "❌ $name ($url)"
    fi
  else
    # HTTP test
    if curl -s --max-time 3 $url >/dev/null; then
      echo "✅ $name ($url)"
    else
      echo "❌ $name ($url)"
    fi
  fi
done
```

### Docker Network Verification

```bash
# Verify network configuration
echo "=== Network Configuration ==="

# List all UMH-related networks
docker network ls | grep -E "(umh|timescale)"

# Check network connectivity
NETWORK_NAME=$(docker network ls --format "{{.Name}}" | grep umh-network)
echo "Main network: $NETWORK_NAME"

# Verify container network attachments
docker network inspect $NETWORK_NAME --format '{{range .Containers}}{{.Name}} {{end}}' | tr ' ' '\n' | sort

# Test internal connectivity
docker exec nodered ping -c 2 hivemq
docker exec grafana ping -c 2 pgbouncer  
docker exec postgres-mcp ping -c 2 pgbouncer
```

### Database Connectivity Test

```bash
# Test database connection chain
echo "=== Database Connectivity ==="

# Test TimescaleDB
docker exec timescaledb pg_isready -U postgres -d umh_v2

# Test PgBouncer
docker exec pgbouncer pg_isready -h localhost -p 5432

# Test external connection via PgBouncer
docker exec -it postgres-mcp psql -h pgbouncer -U grafanareader -d umh_v2 -c "SELECT version();"

# Test PostgreSQL MCP server
curl -s http://localhost:3003 | head -20
```

## 🧪 AI Integration Test

```bash
# Test AI can query database
echo "Test this with your AI client:"
echo '"Show me the schema of the asset table in TimescaleDB"'
echo '"List all hypertables in the umh_v2 database"'
echo '"Query the last 10 entries from the tag table"'

# Test Node-RED API access
echo "Test Node-RED via AI:"
echo '"Show me all flows currently deployed in Node-RED"'
echo '"Create a simple inject node that outputs timestamp"'

# Test Grafana API access  
echo "Test Grafana via AI:"
echo '"Show me all existing datasources in Grafana"'
echo '"Create a simple dashboard with one panel"'
```

## 🔧 Port Configuration

| Service | Internal Port | External Port | Protocol | Purpose |
|---------|---------------|---------------|----------|---------|
| NGINX | 8080 | 8081 | HTTP | Webhook gateway |
| HiveMQ | 1883, 8000 | 1883, 8083 | MQTT/WS | Message broker |
| Node-RED | 1880 | 1880 | HTTP | Flow development |
| Grafana | 3000 | 3000 | HTTP | Dashboards |
| Portainer | 9000 | 9000 | HTTP | Container mgmt |
| PgBouncer | 5432 | 5432 | TCP | Database pool |
| PostgreSQL MCP | 3003 | 3003 | HTTP | AI database access |
| TimescaleDB | 5432 | (internal) | TCP | Time-series DB |
| UMH Core | 8040, 8051 | (internal) | HTTP | Edge gateway |

## 🌐 Network Architecture

```
External Access (localhost/LAN)
├── 1880 → Node-RED (API + UI)
├── 1883 → HiveMQ MQTT
├── 3000 → Grafana (API + UI)  
├── 3003 → PostgreSQL MCP (AI access)
├── 5432 → PgBouncer (database pool)
├── 8081 → NGINX (webhooks)
├── 8083 → HiveMQ WebSocket
└── 9000 → Portainer (container mgmt)

Docker Networks:
├── umh-network (main services)
│   ├── nginx, hivemq, nodered, grafana
│   ├── portainer, pgbouncer, postgres-mcp
│   └── umh-core (external container)
└── timescaledb-network (isolated)
    ├── timescaledb (database)
    └── pgbouncer (bridge)
```

## ⚠️ Common Issues & Fixes

**Port conflicts:**
```bash
# Check what's using a port
lsof -i :3000
# Change port in .env file, restart stack
```

**UMH Core connection:**
```bash
# Get correct network name
docker network ls | grep umh
# Reconnect with proper network name
docker network connect <network-name> umh-core
```

**Database connection:**
```bash
# Reset database connections
docker compose -f examples/historian/docker-compose.historian.yaml restart pgbouncer
# Test connection
docker exec postgres-mcp pg_isready -h pgbouncer
```

**MCP connection issues:**
```bash
# Restart PostgreSQL MCP
docker restart postgres-mcp
# Check logs
docker logs postgres-mcp --tail 20
# Test endpoint
curl http://localhost:3003
```

## 🎯 Success Criteria

✅ All services show "Up" status in `docker ps`  
✅ All health check endpoints return 200  
✅ UMH Core logs show successful connection  
✅ AI can query database via PostgreSQL MCP  
✅ Node-RED and Grafana APIs accessible  
✅ MQTT broker accepts connections  

**Time to deployment: 5 minutes**  
**Time to AI integration: Additional 1 minute**

## Next Steps

1. **Deploy data flows**: Copy from `examples/databridges/flows/` to Management Console
2. **Initialize ERP schema**: Run `examples/databridges/sql/02-erp-schema.sql` if needed
3. **Customize for client**: Update location hierarchy, credentials, flows
4. **Security hardening**: Follow [security checklist](security.md) for production

---

**Agentic Instructions Summary:**
- Single docker compose command deploys everything
- Network names auto-generated with directory prefix  
- All default ports and credentials work out-of-box
- PostgreSQL MCP provides immediate AI database access
- Documentation context configured once, works everywhere