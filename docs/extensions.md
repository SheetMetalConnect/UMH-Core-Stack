# Extending the Stack

Optional tools to enhance your MES capabilities. These connect to the existing stack via TimescaleDB (PgBouncer) or MQTT.

## Database & Data Exploration

### NocoDB

Turns TimescaleDB into a spreadsheet-like interface. Great for exploring data, building simple views, and non-technical users.

```yaml
# Add to docker-compose.yaml or create docker-compose.nocodb.yaml
services:
  nocodb:
    image: nocodb/nocodb:latest
    container_name: nocodb
    restart: unless-stopped
    environment:
      - NC_DB=pg://pgbouncer:5432?u=postgres&p=umhcore&d=umh_v2
    ports:
      - "8080:8080"
    networks:
      - umh-network
```

Access: http://localhost:8080

### Metabase

Business intelligence and analytics. Build dashboards, run SQL queries, share reports.

```yaml
services:
  metabase:
    image: metabase/metabase:latest
    container_name: metabase
    restart: unless-stopped
    environment:
      - MB_DB_TYPE=postgres
      - MB_DB_HOST=pgbouncer
      - MB_DB_PORT=5432
      - MB_DB_DBNAME=umh_v2
      - MB_DB_USER=grafanareader
      - MB_DB_PASS=umhcore
    ports:
      - "3001:3000"
    networks:
      - umh-network
```

Access: http://localhost:3001

---

## Low-Code App Building

### Appsmith

Build operator UIs, internal tools, and dashboards with drag-and-drop. Connects to TimescaleDB for real-time data.

```yaml
services:
  appsmith:
    image: appsmith/appsmith-ce:latest
    container_name: appsmith
    restart: unless-stopped
    ports:
      - "8082:80"
    volumes:
      - appsmith-data:/appsmith-stacks
    networks:
      - umh-network

volumes:
  appsmith-data: {}
```

Access: http://localhost:8082

**Use cases:**
- Operator dashboards with forms and buttons
- Work order management screens
- Quality inspection forms
- Asset management interfaces

### Tooljet

Alternative to Appsmith. Open-source low-code platform.

```yaml
services:
  tooljet:
    image: tooljet/tooljet-ce:latest
    container_name: tooljet
    restart: unless-stopped
    environment:
      - TOOLJET_HOST=http://localhost:8083
      - PG_HOST=pgbouncer
      - PG_DB=umh_v2
      - PG_USER=postgres
      - PG_PASS=umhcore
    ports:
      - "8083:80"
    networks:
      - umh-network
```

Access: http://localhost:8083

### Budibase

Low-code platform for building internal apps quickly.

```yaml
services:
  budibase:
    image: budibase/budibase:latest
    container_name: budibase
    restart: unless-stopped
    ports:
      - "8084:80"
    volumes:
      - budibase-data:/data
    networks:
      - umh-network

volumes:
  budibase-data: {}
```

Access: http://localhost:8084

---

## Workflow Automation

### n8n

Workflow automation similar to Node-RED but with more integrations (Slack, email, APIs). Good for alerts and notifications.

```yaml
services:
  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=admin
      - N8N_BASIC_AUTH_PASSWORD=umhcore
    ports:
      - "5678:5678"
    volumes:
      - n8n-data:/home/node/.n8n
    networks:
      - umh-network

volumes:
  n8n-data: {}
```

Access: http://localhost:5678 (admin / umhcore)

**Use cases:**
- Send Slack/Teams alerts on machine downtime
- Email reports on shift end
- Webhook integrations with ERP systems

---

## Monitoring

### Uptime Kuma

Monitor your stack health. Get alerts when services go down.

```yaml
services:
  uptime-kuma:
    image: louislam/uptime-kuma:latest
    container_name: uptime-kuma
    restart: unless-stopped
    ports:
      - "3002:3001"
    volumes:
      - uptime-kuma-data:/app/data
    networks:
      - umh-network

volumes:
  uptime-kuma-data: {}
```

Access: http://localhost:3002

**Monitor these endpoints:**
- HiveMQ: `tcp://hivemq:1883`
- Grafana: `http://grafana:3000/api/health`
- Node-RED: `http://nodered:1880`
- TimescaleDB: `postgres://pgbouncer:5432`

---

## Database Administration

### Adminer

Lightweight database admin UI. Single PHP file, minimal footprint.

```yaml
services:
  adminer:
    image: adminer:latest
    container_name: adminer
    restart: unless-stopped
    ports:
      - "8085:8080"
    networks:
      - umh-network
```

Access: http://localhost:8085
- System: PostgreSQL
- Server: pgbouncer
- Username: postgres
- Password: umhcore
- Database: umh_v2

---

## Connection Details

All extensions connect to the stack using:

| Resource | Internal Host | Port | Credentials |
|----------|---------------|------|-------------|
| TimescaleDB | pgbouncer | 5432 | postgres / umhcore |
| TimescaleDB (read-only) | pgbouncer | 5432 | grafanareader / umhcore |
| MQTT Broker | hivemq | 1883 | - |
| UMH Core API | umh-core | 8040 | - |

---

## Recommended Combinations

### Basic MES
- **NocoDB** - Data exploration for engineers
- **Appsmith** - Operator dashboards

### Full MES
- **NocoDB** - Data exploration
- **Appsmith** - Operator UIs
- **n8n** - Alerts and integrations
- **Uptime Kuma** - Stack monitoring

### Analytics Focus
- **Metabase** - BI dashboards and reports
- **Grafana** (already included) - Real-time monitoring
