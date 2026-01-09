# Historian Addon

Add local time-series storage and visualization to UMH Core with TimescaleDB and Grafana.

WARNING: See [core deployment README](README.md) for support status and security guidance.

---

## What This Adds

- **TimescaleDB**: PostgreSQL-based time-series database with automatic compression
- **PgBouncer**: Connection pooling in front of TimescaleDB
- **Grafana**: Pre-configured visualization platform with a TimescaleDB datasource
- **Historian Pattern**: Naming convention and examples for persisting time-series data

---

## Prerequisites

1. **Core deployment running**: See [main README](README.md) for core deployment
2. **Historian-specific requirements**:
   - ~4GB RAM for TimescaleDB
   - 2 CPU cores
   - Disk space for time-series data (see Sizing section below)

---

## Quick Start

### 1. Copy historian environment variables

```bash
# From examples/historian/ directory
cat .env.historian.example >> .env
```

### 2. Edit database credentials

```bash
# In .env file, change:
POSTGRES_PASSWORD=umhcore  # Change in production
HISTORIAN_WRITER_PASSWORD=umhcore
HISTORIAN_READER_PASSWORD=umhcore

# Set credentials before first boot; init scripts apply them only once.
```

### 3. Deploy historian addon

```bash
# From examples/historian/ directory
docker compose -f docker-compose.yaml -f docker-compose.historian.yaml up -d
```

### 4. Verify services are healthy

```bash
docker compose -f docker-compose.yaml -f docker-compose.historian.yaml ps
```

Expected output:
```
NAME          IMAGE                                         STATUS
grafana       grafana/grafana:latest                       Up (healthy)
nginx         nginx:alpine                                  Up (healthy)
pgbouncer     edoburu/pgbouncer:v1.24.1-p1                   Up (healthy)
timescaledb   timescale/timescaledb:latest-pg16            Up (healthy)
umh-core      ghcr.io/united-manufacturing-hub/umh-core    Up (healthy)
```

### 5. Access Grafana

Visit: http://localhost:3000
- Username: `admin`
- Password: `umhcore` (change on first login)

Grafana auto-provisions the TimescaleDB datasource via `configs/grafana/provisioning`.

### 6. Verify Installation

```bash
# Test TimescaleDB connection
docker compose exec timescaledb psql -U postgres -d umh_v2 -c "\\dt"
# Should list: asset, tag, tag_string tables

# Test Grafana access
curl -s http://localhost:3000/api/health | grep -q "ok"
# Should exit with status 0 (success)

# Verify PgBouncer is reachable
docker compose exec pgbouncer pg_isready -h pgbouncer
# Should return "accepting connections"
```

**Troubleshooting verification:**
- TimescaleDB connection fails -> Check POSTGRES_PASSWORD in `.env` matches both services
- Grafana shows "Database locked" -> TimescaleDB not fully initialized, wait 30 seconds
- No tables exist -> Database initialization pending, check: `docker compose logs timescaledb`
- No data appearing -> Verify topics contain `_historian` keyword, check: `curl http://localhost:8080/graphql -d '{"query": "{ topics { name } }"}'`

---

## How It Works

### The `_historian` Naming Convention

The `_historian` keyword in topic paths is a naming convention only - it does NOT trigger automatic persistence. You must explicitly create data flows to persist data to TimescaleDB.

**Recommended topic pattern:**
```
umh.v1.<location>.<asset>._historian.<tag-name>
```

**Example topics:**
- `umh.v1.enterprise.factory1.line-a._historian.temperature`
- `umh.v1.enterprise.factory1.pump-3._historian.pressure`
- `umh.v1.enterprise.factory1.robot-1._historian.status`

The `_historian` keyword helps you:
- Identify topics intended for time-series storage
- Organize data flows that write to TimescaleDB
- Follow a consistent pattern across your deployment

### Data Flow Architecture

To persist data to TimescaleDB, you must create two components:

```
1. Protocol Converter (Bridge)
   Reads from devices -> Publishes to UNS Topics
   |
   v
2. UNS Topic: umh.v1.location.asset._historian.tag
   Contains the raw data from devices
   |
   v
3. Data Flow (YOU MUST CREATE THIS)
   Subscribes to _historian topics -> Writes to TimescaleDB
   |
   v
4. TimescaleDB Tables:
   - tag (numeric values)
   - tag_string (text values)
   |
   v
5. Grafana Queries
   Read from TimescaleDB tables (through PgBouncer)
```

**Key Point**: Creating a bridge that publishes to `_historian` topics is NOT enough. You must also create a data flow that subscribes to those topics and writes to TimescaleDB.

### Database Schema

Three main tables are used for storing time-series data:

**`asset` table** - Equipment metadata
```sql
Column      | Type    | Description
------------|---------|------------------
id          | SERIAL  | Primary key
asset_name  | TEXT    | Asset identifier
```

**`tag` table** - Numeric time-series data (hypertable)
```sql
Column      | Type       | Description
------------|------------|------------------
time        | TIMESTAMP  | Data timestamp
asset_id    | INTEGER    | FK to asset table
tag_name    | TEXT       | Tag identifier
value       | DOUBLE     | Numeric value
```

**`tag_string` table** - Text time-series data (hypertable)
```sql
Column      | Type       | Description
------------|------------|------------------
time        | TIMESTAMP  | Data timestamp
asset_id    | INTEGER    | FK to asset table
tag_name    | TEXT       | Tag identifier
value       | TEXT       | String value
```

Both hypertables use:
- Automatic time-based partitioning (1-day chunks)
- Compression after 7 days (configurable)
- Retention policy: 90 days default (configurable)

Initialization scripts live at `configs/timescaledb-init`.

---

## Configuration

### Setting Up Data Flows for Historian

To persist data to TimescaleDB, you need to create TWO components:

#### Step 1: Create a Bridge (Protocol Converter)

Create a bridge that publishes data to `_historian` topics:

```yaml
output:
  kafka:
    topic: umh.v1.${location}.${asset}._historian.${tag_name}
```

This bridge will publish data to the UNS, but the data will NOT be automatically persisted to TimescaleDB.

#### Step 2: Create a Data Flow for Persistence

Create a separate data flow that subscribes to `_historian` topics and writes to TimescaleDB. We provide a pre-built historian flow that you can use.

**To deploy the historian data flow:**

1. Open **Management Console** → **Data Flows** → **Standalone** → **Add**
2. Paste the config from `../databridges/flows/historian.yaml`
3. Deploy the flow

For complete details on how the historian flow works, see `../databridges/flows/historian.yaml`.

**Important**: Both the bridge AND the data flow must be created. The bridge alone will not persist data to TimescaleDB.

### Querying Data in Grafana

**Example query** - Temperature over last hour:

```sql
SELECT time, value
FROM tag
WHERE asset_id = (SELECT id FROM asset WHERE asset_name = 'line-a')
  AND tag_name = 'temperature'
  AND time > NOW() - INTERVAL '1 hour'
ORDER BY time;
```

**Example query** - Status changes:

```sql
SELECT time, value
FROM tag_string
WHERE asset_id = (SELECT id FROM asset WHERE asset_name = 'pump-3')
  AND tag_name = 'status'
  AND time > NOW() - INTERVAL '24 hours'
ORDER BY time;
```

### Database Tuning

Adjust in `.env` or `.env.historian`:

```bash
# Memory allocation (adjust based on available RAM)
TS_TUNE_MEMORY=8GB

# CPU cores to use
TS_TUNE_NUM_CPUS=4
```

Recommended settings by deployment size:

| Deployment Size | Tags | TS_TUNE_MEMORY | TS_TUNE_NUM_CPUS |
|----------------|------|----------------|------------------|
| Small          | <100 | 4GB            | 2                |
| Medium         | 100-1000 | 8GB        | 4                |
| Large          | >1000 | 16GB          | 8                |

---

## Security

**CRITICAL**: Change default passwords before production use.

See [core security documentation](security/umh-core/deployment-security.md) for general hardening.

### Database Credentials

```bash
# Generate strong password
openssl rand -base64 32

# Update in .env file
POSTGRES_PASSWORD=<generated-password>
```

### Port Exposure

For production, remove port 5432 mapping in `docker-compose.historian.yaml` and use SSH tunnel for remote access.

### Grafana Access

Change admin password immediately on first login.

---

## Maintenance

### Backup Database

```bash
# Create backup
docker compose exec timescaledb pg_dump -U postgres umh_v2 | gzip > backup-$(date +%Y%m%d).sql.gz

# Restore backup
gunzip < backup-20250124.sql.gz | docker compose exec -T timescaledb psql -U postgres umh_v2
```

### Monitor Disk Usage

```bash
# Check database size
docker compose exec timescaledb psql -U postgres -d umh_v2 -c "
  SELECT pg_size_pretty(pg_database_size('umh_v2'));
"

# Check table sizes
docker compose exec timescaledb psql -U postgres -d umh_v2 -c "
  SELECT
    schemaname,
    tablename,
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
  FROM pg_tables
  WHERE schemaname = 'public'
  ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
"
```

### Adjust Retention Policy

```bash
# Change retention to 30 days
docker compose exec timescaledb psql -U postgres -d umh_v2 -c "
  SELECT remove_retention_policy('tag');
  SELECT add_retention_policy('tag', INTERVAL '30 days');

  SELECT remove_retention_policy('tag_string');
  SELECT add_retention_policy('tag_string', INTERVAL '30 days');
"
```
