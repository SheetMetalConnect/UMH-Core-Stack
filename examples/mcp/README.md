# MCP Addon

AI/LLM integration via [Model Context Protocol](https://www.anthropic.com/mcp) for database access.

## What This Adds

- **postgres-mcp** (port 3003) - AI assistant access to TimescaleDB via PgBouncer

Provides AI assistants with read-only database access for querying time-series data, ERP tables, and generating insights.

## Prerequisites

**Requires historian addon** to be running (provides PgBouncer and TimescaleDB):

```bash
docker compose -f ../../docker-compose.yaml \
  -f ../historian/docker-compose.historian.yaml up -d
```

## Quick Start

```bash
# Start MCP addon (requires historian to be running)
docker compose -f ../../docker-compose.yaml \
  -f ../historian/docker-compose.historian.yaml \
  -f docker-compose.mcp.yaml up -d
```

## AI Client Setup

Add to your AI client configuration (Claude Desktop, Claude Code, etc.):

```json
{
  "mcpServers": {
    "umh-database": {
      "command": "npx",
      "args": [
        "@modelcontextprotocol/server-postgres",
        "postgresql://grafanareader:umhcore@<host-ip>:5432/umh_v2"
      ]
    }
  }
}
```

Replace `<host-ip>` with your Docker host IP address.

## Environment Variables

Add to your `.env` file (defaults shown):

```bash
# PostgreSQL MCP Server
MCP_POSTGRES_PORT=3003
MCP_POSTGRES_ACCESS=restricted

# Database credentials (from historian addon)
HISTORIAN_READER_USER=grafanareader
HISTORIAN_READER_PASSWORD=umhcore
POSTGRES_DB=umh_v2
```

## Use Cases

**Database Queries:**
- "Show me the last 100 temperature readings from line-a"
- "What's the average production rate for the last 7 days?"
- "Find all sales orders created in the last 24 hours"

**Data Analysis:**
- "Analyze temperature trends over the past month"
- "What patterns do you see in the production data?"
- "Compare OEE metrics across different assets"

**Schema Exploration:**
- "What tables are available in the database?"
- "Describe the structure of the erp_sales_order table"
- "Show me all hypertables and their compression settings"

## Security

**Read-only access:** The MCP server uses the `grafanareader` role which has SELECT-only permissions.

**Change default credentials in production:**

```bash
# Generate secure password
openssl rand -base64 32

# Update in .env
HISTORIAN_READER_PASSWORD=<generated-password>
```

**Network restrictions:**
- MCP server accessible via internal Docker network
- No direct external exposure
- AI clients connect via exposed port 3003

## Direct Node-RED & Grafana API Access

For AI assistant integration with Node-RED flows and Grafana dashboards, use their REST APIs directly:

**Node-RED API** (port 1880):
- Flow management, deployment, debugging
- Use client-side MCP tools or direct HTTP requests

**Grafana API** (port 3000):
- Dashboard creation, panel management, queries
- Use client-side MCP tools or direct HTTP requests

See [UMH Docs](https://docs.umh.app/) for API documentation.

## Troubleshooting

**Verify MCP server:**
```bash
curl http://localhost:3003/health
docker logs postgres-mcp
```

**Connection issues:**
```bash
# Ensure historian is running
docker ps | grep -E "(pgbouncer|timescaledb)"

# Test database connection
docker exec postgres-mcp psql -h pgbouncer -U grafanareader -d umh_v2 -c "SELECT 1"
```

**Permission errors:**
- MCP server uses read-only `grafanareader` role
- Cannot INSERT, UPDATE, or DELETE
- For write operations, use Node-RED flows or direct database access

## See Also

- [Model Context Protocol](https://www.anthropic.com/mcp)
- [PostgreSQL MCP Server](https://github.com/modelcontextprotocol/servers/tree/main/src/postgres)
- [Historian Addon](../historian) - Required dependency
- [Main README](../../README.md) - Full stack documentation
