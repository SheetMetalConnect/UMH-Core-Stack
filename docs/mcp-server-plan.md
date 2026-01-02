# MCP Server for UMH Core Stack - Implementation Plan

## Executive Summary

Add a custom MCP (Model Context Protocol) server to the UMH Core Stack that enables AI assistants to query manufacturing data across both:
- **Live MQTT namespace** (current tag values)
- **TimescaleDB historian** (historical time-series data)

This enables conversational queries like:
- "What are all the tags for the pump asset?"
- "Show me the last 100 temperature readings for line1"
- "What was the energy consumption over the last 24 hours?"
- "List recent work orders for this asset"

---

## Current Stack Analysis

### Available Data Sources

| Source | Access | Data Type |
|--------|--------|-----------|
| HiveMQ MQTT | `hivemq:1883` | Live tag values, topics |
| TimescaleDB (via PgBouncer) | `pgbouncer:5432` | Historical time-series |

### Existing Database Schema

```
Database: umh_v2

┌─────────────────────────────────────────────────────────────┐
│  asset                                                       │
│  ├── id (PK, SERIAL)                                        │
│  ├── asset_name (UNIQUE) - e.g., "factory.line1.pump"       │
│  ├── location                                                │
│  ├── created_at                                              │
│  └── updated_at                                              │
├─────────────────────────────────────────────────────────────┤
│  tag (HYPERTABLE - numeric values)                          │
│  ├── time (TIMESTAMPTZ, partitioned)                        │
│  ├── asset_id (FK → asset.id)                               │
│  ├── tag_name - e.g., "temperature", "energy"               │
│  ├── value (DOUBLE PRECISION)                               │
│  └── origin - e.g., "mqtt"                                  │
├─────────────────────────────────────────────────────────────┤
│  tag_string (HYPERTABLE - string values)                    │
│  ├── time (TIMESTAMPTZ, partitioned)                        │
│  ├── asset_id (FK → asset.id)                               │
│  ├── tag_name - e.g., "status", "mode"                      │
│  ├── value (TEXT)                                           │
│  └── origin                                                 │
└─────────────────────────────────────────────────────────────┘
```

### MQTT Topic Structure

```
umh/v1/<location>/<asset>/<tag>

Examples:
  umh/v1/factory/line1/temperature
  umh/v1/enterprise.site1/pump/energy
  umh/v1/factory/conveyor/_work-order
```

---

## Proposed Architecture

### MCP Server Container

```
┌─────────────────────────────────────────────────────────────────┐
│                     MCP Server Container                         │
│                                                                  │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐       │
│  │  MQTT Client │    │   PostgreSQL │    │  MCP Protocol│       │
│  │  (paho-mqtt) │    │    Client    │    │   Handler    │       │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘       │
│         │                   │                   │                │
│         ▼                   ▼                   ▼                │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │                    Tool Implementations                   │   │
│  │  • list_topics      • get_tag_history                    │   │
│  │  • get_current_value • list_assets                       │   │
│  │  • search_tags       • query_work_orders                 │   │
│  │  • get_tag_stats     • cross_reference                   │   │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│                     stdio / SSE / HTTP                           │
└──────────────────────────────┬──────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
        ┌──────────┐    ┌──────────┐    ┌──────────────┐
        │  HiveMQ  │    │ PgBouncer│    │ Claude/AI    │
        │  :1883   │    │  :5432   │    │   Client     │
        └──────────┘    └──────────┘    └──────────────┘
```

### Docker Compose Addition

```yaml
# examples/mcp/docker-compose.mcp.yaml

services:
  umh-mcp-server:
    build:
      context: ./mcp-server
      dockerfile: Dockerfile
    container_name: umh-mcp-server
    restart: unless-stopped
    environment:
      # MQTT Configuration
      - MQTT_BROKER=hivemq
      - MQTT_PORT=1883
      - MQTT_TOPIC_PREFIX=umh/#

      # Database Configuration
      - DB_HOST=pgbouncer
      - DB_PORT=5432
      - DB_NAME=umh_v2
      - DB_USER=${HISTORIAN_READER_USER:-grafanareader}
      - DB_PASSWORD=${HISTORIAN_READER_PASSWORD:-umhcore}

      # MCP Configuration
      - MCP_TRANSPORT=stdio  # or sse, http
      - MCP_PORT=3001

      # Cache Configuration
      - TOPIC_CACHE_TTL=60  # seconds
      - VALUE_CACHE_TTL=5   # seconds
    ports:
      - "${PORT_MCP:-3001}:3001"
    volumes:
      - mcp-cache:/app/cache
    networks:
      - umh-network
    depends_on:
      hivemq:
        condition: service_healthy
      pgbouncer:
        condition: service_started
    healthcheck:
      test: ["CMD", "python", "-c", "import socket; s=socket.socket(); s.connect(('localhost', 3001)); s.close()"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 15s

volumes:
  mcp-cache: {}
```

---

## MCP Tools Specification

### 1. `list_topics` - Discover MQTT Topics

**Purpose:** List all active MQTT topics in the namespace

```json
{
  "name": "list_topics",
  "description": "List all active MQTT topics in the UMH namespace",
  "inputSchema": {
    "type": "object",
    "properties": {
      "pattern": {
        "type": "string",
        "description": "Optional wildcard pattern (e.g., 'umh/v1/factory/*')"
      },
      "include_values": {
        "type": "boolean",
        "default": false,
        "description": "Include last known values"
      }
    }
  }
}
```

**Example Response:**
```json
{
  "topics": [
    {"topic": "umh/v1/factory/line1/temperature", "last_value": 42.5, "last_seen": "2024-01-15T10:30:00Z"},
    {"topic": "umh/v1/factory/line1/energy", "last_value": 1250.3, "last_seen": "2024-01-15T10:30:01Z"},
    {"topic": "umh/v1/factory/pump/_work-order", "last_value": {...}, "last_seen": "2024-01-15T10:25:00Z"}
  ],
  "count": 3
}
```

### 2. `get_current_value` - Get Live Tag Value

**Purpose:** Get the current value of a specific tag from MQTT

```json
{
  "name": "get_current_value",
  "description": "Get the current live value of a tag from MQTT",
  "inputSchema": {
    "type": "object",
    "properties": {
      "asset": {
        "type": "string",
        "description": "Asset identifier (e.g., 'factory.line1' or 'pump')"
      },
      "tag": {
        "type": "string",
        "description": "Tag name (e.g., 'temperature', 'energy')"
      },
      "topic": {
        "type": "string",
        "description": "Full MQTT topic (alternative to asset+tag)"
      }
    },
    "oneOf": [
      {"required": ["asset", "tag"]},
      {"required": ["topic"]}
    ]
  }
}
```

### 3. `search_tags` - Search for Tags

**Purpose:** Search for tags matching criteria across both MQTT and historian

```json
{
  "name": "search_tags",
  "description": "Search for tags matching a pattern",
  "inputSchema": {
    "type": "object",
    "properties": {
      "query": {
        "type": "string",
        "description": "Search query (e.g., 'temperature', 'energy', 'pump')"
      },
      "asset_filter": {
        "type": "string",
        "description": "Filter by asset name pattern"
      },
      "source": {
        "type": "string",
        "enum": ["mqtt", "historian", "both"],
        "default": "both"
      }
    },
    "required": ["query"]
  }
}
```

### 4. `get_tag_history` - Query Historical Data

**Purpose:** Retrieve historical values from TimescaleDB

```json
{
  "name": "get_tag_history",
  "description": "Query historical time-series data for a tag",
  "inputSchema": {
    "type": "object",
    "properties": {
      "asset": {
        "type": "string",
        "description": "Asset identifier"
      },
      "tag": {
        "type": "string",
        "description": "Tag name"
      },
      "limit": {
        "type": "integer",
        "default": 100,
        "maximum": 10000,
        "description": "Number of records to return"
      },
      "time_range": {
        "type": "object",
        "properties": {
          "start": {"type": "string", "format": "date-time"},
          "end": {"type": "string", "format": "date-time"}
        }
      },
      "aggregation": {
        "type": "string",
        "enum": ["none", "avg", "min", "max", "sum", "count"],
        "default": "none"
      },
      "bucket_interval": {
        "type": "string",
        "description": "Time bucket for aggregation (e.g., '1 minute', '1 hour', '1 day')"
      },
      "order": {
        "type": "string",
        "enum": ["asc", "desc"],
        "default": "desc"
      }
    },
    "required": ["asset", "tag"]
  }
}
```

**Example SQL Generated:**
```sql
-- Simple query: last 100 records
SELECT time, value, origin
FROM tag
WHERE asset_id = (SELECT id FROM asset WHERE asset_name = 'factory.line1')
  AND tag_name = 'temperature'
ORDER BY time DESC
LIMIT 100;

-- Aggregated query: hourly averages for last 24 hours
SELECT time_bucket('1 hour', time) AS bucket,
       AVG(value) AS avg_value,
       MIN(value) AS min_value,
       MAX(value) AS max_value,
       COUNT(*) AS sample_count
FROM tag
WHERE asset_id = (SELECT id FROM asset WHERE asset_name = 'factory.line1')
  AND tag_name = 'energy'
  AND time > NOW() - INTERVAL '24 hours'
GROUP BY bucket
ORDER BY bucket DESC;
```

### 5. `get_tag_stats` - Statistical Summary

**Purpose:** Get statistical summary of a tag's historical data

```json
{
  "name": "get_tag_stats",
  "description": "Get statistical summary for a tag",
  "inputSchema": {
    "type": "object",
    "properties": {
      "asset": {"type": "string"},
      "tag": {"type": "string"},
      "time_range": {
        "type": "object",
        "properties": {
          "start": {"type": "string", "format": "date-time"},
          "end": {"type": "string", "format": "date-time"}
        }
      }
    },
    "required": ["asset", "tag"]
  }
}
```

**Response:**
```json
{
  "asset": "factory.line1",
  "tag": "temperature",
  "stats": {
    "count": 86400,
    "min": 18.2,
    "max": 45.7,
    "avg": 32.4,
    "stddev": 5.2,
    "first_value": 28.1,
    "last_value": 34.2,
    "first_time": "2024-01-14T10:30:00Z",
    "last_time": "2024-01-15T10:30:00Z"
  }
}
```

### 6. `list_assets` - List All Assets

**Purpose:** List all known assets from the historian

```json
{
  "name": "list_assets",
  "description": "List all assets in the historian",
  "inputSchema": {
    "type": "object",
    "properties": {
      "pattern": {
        "type": "string",
        "description": "Filter pattern (e.g., 'factory.*')"
      },
      "include_tags": {
        "type": "boolean",
        "default": false,
        "description": "Include list of tags for each asset"
      }
    }
  }
}
```

### 7. `cross_reference` - Compare Live vs Historical

**Purpose:** Cross-reference current MQTT value with historical data

```json
{
  "name": "cross_reference",
  "description": "Compare current value with historical context",
  "inputSchema": {
    "type": "object",
    "properties": {
      "asset": {"type": "string"},
      "tag": {"type": "string"},
      "comparison_period": {
        "type": "string",
        "default": "24 hours",
        "description": "Historical period for comparison"
      }
    },
    "required": ["asset", "tag"]
  }
}
```

**Response:**
```json
{
  "current": {
    "value": 42.5,
    "timestamp": "2024-01-15T10:30:00Z",
    "source": "mqtt"
  },
  "historical": {
    "period": "24 hours",
    "avg": 38.2,
    "min": 32.1,
    "max": 45.8,
    "stddev": 3.4
  },
  "analysis": {
    "deviation_from_avg": 4.3,
    "deviation_percentage": 11.3,
    "percentile": 85,
    "status": "above_average"
  }
}
```

---

## Work Order Support

### Required Schema Addition

Work orders are not currently in the schema. Add to `configs/timescaledb-init/`:

```sql
-- 02-work-order-schema.sql

-- Work Order table
CREATE TABLE IF NOT EXISTS work_order (
    id SERIAL PRIMARY KEY,
    work_order_id VARCHAR(255) NOT NULL,
    asset_id INTEGER REFERENCES asset(id) ON DELETE CASCADE,
    status VARCHAR(50) NOT NULL DEFAULT 'created',
    product_id VARCHAR(255),
    quantity_target INTEGER,
    quantity_actual INTEGER DEFAULT 0,
    start_time TIMESTAMPTZ,
    end_time TIMESTAMPTZ,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW(),
    metadata JSONB
);

-- Work Order Events (time-series)
CREATE TABLE IF NOT EXISTS work_order_event (
    time TIMESTAMPTZ NOT NULL,
    work_order_id INTEGER REFERENCES work_order(id) ON DELETE CASCADE,
    event_type VARCHAR(50) NOT NULL,
    event_data JSONB,
    origin VARCHAR(255)
);

-- Create hypertable for events
SELECT create_hypertable('work_order_event', 'time', if_not_exists => TRUE);

-- Indexes
CREATE INDEX idx_work_order_asset ON work_order(asset_id);
CREATE INDEX idx_work_order_status ON work_order(status);
CREATE INDEX idx_work_order_event_wo ON work_order_event(work_order_id);

-- Permissions
GRANT SELECT, INSERT, UPDATE ON work_order TO kafkatopostgresqlv2;
GRANT SELECT, INSERT ON work_order_event TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE work_order_id_seq TO kafkatopostgresqlv2;
GRANT SELECT ON work_order, work_order_event TO grafanareader;
```

### Work Order MCP Tool

```json
{
  "name": "query_work_orders",
  "description": "Query work order data",
  "inputSchema": {
    "type": "object",
    "properties": {
      "asset": {
        "type": "string",
        "description": "Filter by asset"
      },
      "status": {
        "type": "string",
        "enum": ["created", "started", "completed", "cancelled"],
        "description": "Filter by status"
      },
      "work_order_id": {
        "type": "string",
        "description": "Specific work order ID"
      },
      "limit": {
        "type": "integer",
        "default": 50
      },
      "include_events": {
        "type": "boolean",
        "default": false
      },
      "time_range": {
        "type": "object",
        "properties": {
          "start": {"type": "string", "format": "date-time"},
          "end": {"type": "string", "format": "date-time"}
        }
      }
    }
  }
}
```

---

## Implementation Details

### Technology Stack

| Component | Technology | Reason |
|-----------|------------|--------|
| Language | Python 3.11+ | MCP SDK available, async support |
| MCP SDK | `mcp` (official) | Standard protocol implementation |
| MQTT | `paho-mqtt` or `aiomqtt` | Async MQTT client |
| PostgreSQL | `asyncpg` | High-performance async driver |
| Caching | `cachetools` | In-memory TTL cache |
| Framework | `asyncio` | Event-driven architecture |

### Project Structure

```
examples/mcp/
├── docker-compose.mcp.yaml      # Compose overlay
├── mcp-server/
│   ├── Dockerfile
│   ├── requirements.txt
│   ├── pyproject.toml
│   └── src/
│       ├── __init__.py
│       ├── main.py              # Entry point
│       ├── server.py            # MCP server setup
│       ├── config.py            # Configuration
│       ├── clients/
│       │   ├── __init__.py
│       │   ├── mqtt.py          # MQTT client
│       │   └── postgres.py      # PostgreSQL client
│       ├── tools/
│       │   ├── __init__.py
│       │   ├── topics.py        # list_topics, get_current_value
│       │   ├── history.py       # get_tag_history, get_tag_stats
│       │   ├── assets.py        # list_assets, search_tags
│       │   ├── work_orders.py   # query_work_orders
│       │   └── cross_ref.py     # cross_reference
│       └── cache/
│           ├── __init__.py
│           └── topic_cache.py   # MQTT topic caching
└── README.md                    # Usage documentation
```

### Dockerfile

```dockerfile
FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY src/ ./src/

# Create non-root user
RUN useradd -m -u 1000 mcp && chown -R mcp:mcp /app
USER mcp

# Health check port
EXPOSE 3001

# Run MCP server
CMD ["python", "-m", "src.main"]
```

### requirements.txt

```
mcp>=1.0.0
paho-mqtt>=2.0.0
asyncpg>=0.29.0
pydantic>=2.0.0
pydantic-settings>=2.0.0
cachetools>=5.3.0
python-json-logger>=2.0.0
```

---

## Caching Strategy

### MQTT Topic Cache

```python
class TopicCache:
    """
    Maintains cache of active MQTT topics and their last values.
    - Subscribes to umh/# on startup
    - Updates cache on each message
    - Provides fast topic discovery
    """

    def __init__(self, ttl: int = 60):
        self.topics: Dict[str, TopicEntry] = {}
        self.ttl = ttl  # Inactive topics removed after TTL

    async def on_message(self, topic: str, payload: bytes):
        self.topics[topic] = TopicEntry(
            topic=topic,
            value=json.loads(payload),
            last_seen=datetime.now(UTC),
            retained=False
        )

    def get_active_topics(self, pattern: str = None) -> List[TopicEntry]:
        now = datetime.now(UTC)
        active = [
            t for t in self.topics.values()
            if (now - t.last_seen).total_seconds() < self.ttl
        ]
        if pattern:
            active = [t for t in active if fnmatch(t.topic, pattern)]
        return active
```

### Query Cache

```python
# Cache expensive historian queries
@cached(cache=TTLCache(maxsize=100, ttl=30))
async def get_asset_id(asset_name: str) -> int:
    """Cache asset ID lookups"""
    ...

@cached(cache=TTLCache(maxsize=50, ttl=60))
async def get_asset_tags(asset_id: int) -> List[str]:
    """Cache tag lists per asset"""
    ...
```

---

## Security Considerations

### Database Access

- Use read-only user (`grafanareader`) by default
- Support optional write user for work order updates
- Connection via PgBouncer for pooling

### MQTT Access

- Subscribe-only (no publish from MCP server)
- Optional authentication if HiveMQ configured

### Rate Limiting

```python
# Prevent query flooding
RATE_LIMITS = {
    "get_tag_history": RateLimit(calls=10, period=60),  # 10 calls/minute
    "list_topics": RateLimit(calls=30, period=60),
    "cross_reference": RateLimit(calls=20, period=60),
}
```

---

## Usage Examples

### Example 1: Explore Available Data

```
User: "What data is available from the factory floor?"

MCP Tools Used:
1. list_assets(pattern="factory.*", include_tags=true)
2. list_topics(pattern="umh/v1/factory/*")

Response: "I found 3 assets on the factory floor:
- factory.line1: temperature, energy, status, count
- factory.line2: temperature, energy, vibration
- factory.conveyor: speed, state

There are currently 12 active MQTT topics streaming data."
```

### Example 2: Investigate Anomaly

```
User: "The temperature on line1 seems high. What's going on?"

MCP Tools Used:
1. cross_reference(asset="factory.line1", tag="temperature", comparison_period="24 hours")
2. get_tag_history(asset="factory.line1", tag="temperature", limit=100)

Response: "Current temperature is 45.2°C, which is in the 95th percentile
compared to the last 24 hours (average: 32.4°C). Temperature started rising
about 2 hours ago. Here's the trend..."
```

### Example 3: Work Order Status

```
User: "What work orders are running on line1?"

MCP Tools Used:
1. query_work_orders(asset="factory.line1", status="started", include_events=true)

Response: "Work order WO-2024-0142 is currently in progress:
- Product: Widget-A
- Target: 500 units
- Completed: 347 units (69%)
- Started: 2 hours ago
- Estimated completion: 45 minutes"
```

---

## Deployment Steps

### Step 1: Schema Update (if using work orders)

```bash
# Add work order tables
docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml \
  exec timescaledb psql -U postgres -d umh_v2 -f /docker-entrypoint-initdb.d/02-work-order-schema.sql
```

### Step 2: Build and Deploy MCP Server

```bash
# Start with MCP server
docker compose -f docker-compose.yaml \
  -f examples/historian/docker-compose.historian.yaml \
  -f examples/mcp/docker-compose.mcp.yaml \
  up -d --build
```

### Step 3: Configure AI Client

For Claude Desktop (`claude_desktop_config.json`):
```json
{
  "mcpServers": {
    "umh-historian": {
      "command": "docker",
      "args": ["exec", "-i", "umh-mcp-server", "python", "-m", "src.main"],
      "env": {}
    }
  }
}
```

Or via SSE transport:
```json
{
  "mcpServers": {
    "umh-historian": {
      "url": "http://localhost:3001/sse"
    }
  }
}
```

---

## Implementation Phases

### Phase 1: Core Infrastructure
- [ ] Create project structure
- [ ] Implement PostgreSQL client with connection pooling
- [ ] Implement MQTT client with topic caching
- [ ] Set up MCP server skeleton

### Phase 2: Basic Tools
- [ ] `list_assets` - Query asset table
- [ ] `list_topics` - Return cached MQTT topics
- [ ] `get_current_value` - Get from MQTT cache
- [ ] `get_tag_history` - Basic historian query

### Phase 3: Advanced Queries
- [ ] `get_tag_stats` - Statistical summaries
- [ ] `search_tags` - Pattern matching across sources
- [ ] `cross_reference` - Live vs historical comparison
- [ ] Time-series aggregations with buckets

### Phase 4: Work Orders
- [ ] Schema migration script
- [ ] `query_work_orders` tool
- [ ] Work order event tracking
- [ ] DataFlow for work order ingestion

### Phase 5: Production Readiness
- [ ] Rate limiting
- [ ] Error handling and retries
- [ ] Logging and observability
- [ ] Documentation and examples
- [ ] Tests

---

## Open Questions

1. **Transport Protocol**: Should we default to stdio (simpler) or SSE/HTTP (network accessible)?

2. **Work Order Schema**: Should work orders use a topic convention like `umh/v1/<asset>/_work-order` or a separate namespace?

3. **Caching Strategy**: How aggressive should MQTT caching be? Topics inactive for how long should be pruned?

4. **Query Limits**: What are sensible defaults for `limit` on historical queries? (proposed: 100, max: 10000)

5. **Write Access**: Should the MCP server have any write capabilities (e.g., creating work orders)?

---

## Files to Create

| File | Purpose |
|------|---------|
| `examples/mcp/docker-compose.mcp.yaml` | Docker Compose overlay |
| `examples/mcp/mcp-server/Dockerfile` | Container build |
| `examples/mcp/mcp-server/requirements.txt` | Python dependencies |
| `examples/mcp/mcp-server/src/main.py` | Entry point |
| `examples/mcp/mcp-server/src/server.py` | MCP server setup |
| `examples/mcp/mcp-server/src/config.py` | Configuration |
| `examples/mcp/mcp-server/src/clients/*.py` | MQTT/PostgreSQL clients |
| `examples/mcp/mcp-server/src/tools/*.py` | Tool implementations |
| `examples/mcp/README.md` | Usage documentation |
| `configs/timescaledb-init/02-work-order-schema.sql` | Work order tables |
| `docs/mcp-server.md` | User documentation |
