# MCP (Model Context Protocol) Addon

This addon adds MCP servers for Node-RED and Grafana to enable AI/LLM integration with the UMH stack.

## What is MCP?

[Model Context Protocol (MCP)](https://www.anthropic.com/mcp) is an open standard that enables secure connections between LLM applications (like Claude, ChatGPT) and external services. MCP servers provide tools and context to AI assistants, allowing them to:

- Read and interact with your Node-RED flows
- Query and create Grafana dashboards  
- Access real-time data from your UMH deployment
- Provide intelligent automation suggestions

## Services Included

| Service | Purpose | Port | MCP Endpoint |
|---------|---------|------|--------------|
| **nodered-mcp** | Node-RED flows automation and AI-assisted development | 3001 | `http://<host>:3001` |
| **grafana-mcp** | Dashboard creation and data visualization assistance | 3002 | `http://<host>:3002` |

## Prerequisites

This addon requires the base UMH Core services to be running:

```bash
# Start core services first
docker compose -f ../../docker-compose.yaml up -d

# For full historian stack
docker compose -f ../../docker-compose.yaml -f ../historian/docker-compose.historian.yaml up -d
```

## Quick Start

1. **Start MCP servers alongside existing services:**
   ```bash
   # Core + MCP only
   docker compose -f ../../docker-compose.yaml -f docker-compose.mcp.yaml up -d
   
   # Core + Historian + MCP (recommended)
   docker compose -f ../../docker-compose.yaml \
     -f ../historian/docker-compose.historian.yaml \
     -f docker-compose.mcp.yaml up -d
   ```

2. **Configure your AI client** (Claude Desktop, VSCode, etc.):
   ```json
   {
     "mcpServers": {
       "nodered": {
         "command": "npx",
         "args": ["@modelcontextprotocol/client-http", "http://<your-host-ip>:3001"]
       },
       "grafana": {
         "command": "npx", 
         "args": ["@modelcontextprotocol/client-http", "http://<your-host-ip>:3002"]
       }
     }
   }
   ```

3. **Verify MCP servers are running:**
   ```bash
   # Check health endpoints
   curl http://<host-ip>:3001/health  # Node-RED MCP
   curl http://<host-ip>:3002/health  # Grafana MCP
   
   # View logs
   docker logs nodered-mcp
   docker logs grafana-mcp
   ```

## Configuration

### Environment Variables

Add these to your `.env` file (see `.env.example` for defaults):

```bash
# MCP Server Ports
MCP_NODERED_PORT=3001
MCP_GRAFANA_PORT=3002

# MCP Server Names (for client identification)
MCP_NODERED_NAME=nodered
MCP_GRAFANA_NAME=grafana

# Node-RED Authentication (if enabled)
NODERED_MCP_USERNAME=
NODERED_MCP_PASSWORD=

# Grafana credentials (inherited from historian addon)
GF_ADMIN_USER=admin
GF_ADMIN_PASSWORD=umhcore
```

### Security Considerations

1. **Change default credentials:**
   ```bash
   # In production, update Grafana password
   GF_ADMIN_PASSWORD=your-secure-password
   ```

2. **Network access:**
   - MCP ports (3001, 3002) are exposed to the host network
   - In production, consider using a reverse proxy or VPN
   - Firewall rules should restrict access to authorized clients

3. **Authentication:**
   - Node-RED MCP supports HTTP Basic auth if Node-RED has authentication enabled
   - Grafana MCP uses Grafana's admin credentials

## AI Client Integration

### Claude Desktop

Add to `~/.config/claude-desktop/claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "umh-nodered": {
      "command": "npx",
      "args": ["@modelcontextprotocol/client-http", "http://192.168.1.100:3001"],
      "env": {}
    },
    "umh-grafana": {
      "command": "npx", 
      "args": ["@modelcontextprotocol/client-http", "http://192.168.1.100:3002"],
      "env": {}
    }
  }
}
```

### Claude Code CLI

```bash
# Add MCP servers to your user config
claude mcp add --transport http --scope user umh-nodered http://<host-ip>:3001
claude mcp add --transport http --scope user umh-grafana http://<host-ip>:3002

# Verify connections
claude mcp list
```

### VSCode with Continue

Add to `.continue/config.json`:

```json
{
  "mcpServers": [
    {
      "name": "umh-nodered",
      "url": "http://192.168.1.100:3001"
    },
    {
      "name": "umh-grafana", 
      "url": "http://192.168.1.100:3002"
    }
  ]
}
```

## Use Cases

### Node-RED MCP Capabilities

- **Flow Development:** "Create a flow that reads sensor data from MQTT and writes to TimescaleDB"
- **Debugging:** "Analyze this Node-RED flow and find potential issues"
- **Documentation:** "Generate documentation for all flows in this workspace"
- **Optimization:** "Suggest performance improvements for this data processing flow"

### Grafana MCP Capabilities

- **Dashboard Creation:** "Create a dashboard showing production metrics from TimescaleDB"
- **Query Building:** "Help me write a query to show average temperature by hour"
- **Panel Management:** "Add a time-series panel showing OEE trends"
- **Datasource Integration:** "Query the pre-configured TimescaleDB datasource"
- **Alerting:** "Set up alerts for when machine temperature exceeds 80°C"
- **Data Analysis:** "What patterns do you see in this time-series data?"

**Note:** Grafana MCP automatically uses the pre-configured TimescaleDB datasource via PgBouncer, so all queries run against your UMH historian data.

## Networking

MCP servers integrate with the existing UMH network architecture:

```
External MCP Client (Claude, VSCode, etc.)
        ↓
    <host-ip>:3001 (Node-RED MCP)
    <host-ip>:3002 (Grafana MCP)
        ↓
    umh-network (Docker Bridge)
        ↓
    nodered:1880 (Node-RED API)
    grafana:3000 (Grafana API)
```

Both MCP servers:
- Connect to the `umh-network` Docker network
- Communicate with Node-RED and Grafana using internal Docker DNS
- Expose HTTP endpoints for MCP client connections
- Follow the same security and networking patterns as other UMH services

## Troubleshooting

### MCP Server Won't Start

1. **Check dependencies:**
   ```bash
   # Ensure core services are running
   docker ps | grep -E "(nodered|grafana)"
   ```

2. **Check port conflicts:**
   ```bash
   # Verify ports 3001, 3002 are available
   lsof -i :3001
   lsof -i :3002
   ```

3. **Check logs:**
   ```bash
   docker logs nodered-mcp --tail 20
   docker logs grafana-mcp --tail 20
   ```

### MCP Client Can't Connect

1. **Verify network connectivity:**
   ```bash
   # Test from your AI client machine
   curl http://<umh-host-ip>:3001/health
   curl http://<umh-host-ip>:3002/health
   ```

2. **Check firewall rules:**
   ```bash
   # Ensure ports 3001, 3002 are open
   telnet <umh-host-ip> 3001
   telnet <umh-host-ip> 3002
   ```

3. **Verify credentials:**
   - Check Grafana credentials in `.env` file
   - Test manual API access: `curl -u admin:umhcore http://<host>:3000/api/health`

### Authentication Issues

1. **Node-RED authentication:**
   ```bash
   # If Node-RED has auth enabled, set credentials
   export NODERED_MCP_USERNAME=your-username
   export NODERED_MCP_PASSWORD=your-password
   ```

2. **Grafana authentication:**
   ```bash
   # Option A: Create service account token (recommended)
   docker exec grafana grafana-cli admin data-source create-service-account \
     --name "MCP Integration" --role Admin
   
   # Option B: Verify admin credentials  
   docker exec grafana grafana-cli admin reset-admin-password umhcore
   ```

## Stopping MCP Addon

```bash
# Stop MCP services only
docker compose -f docker-compose.mcp.yaml down

# Stop everything including core services
docker compose -f ../../docker-compose.yaml \
  -f ../historian/docker-compose.historian.yaml \
  -f docker-compose.mcp.yaml down
```

## See Also

- [UMH Core Documentation](../../README.md)
- [Networking Guide](../../docs/networking.md) 
- [Node-RED MCP Server](https://github.com/karavaev-evgeniy/node-red-mcp-server)
- [Grafana MCP Server](https://github.com/grafana/mcp-grafana)
- [Model Context Protocol Spec](https://www.anthropic.com/mcp)
- [Claude Desktop Setup](https://claude.ai/desktop)