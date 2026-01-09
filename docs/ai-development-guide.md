# AI Development Guide for UMH Core

This guide shows how to set up and use Claude Code (or other AI assistants) for optimal development with the UMH Core repository, including access to documentation and live system integration via MCP servers.

## Overview: AI-Assisted UMH Development

This repository is designed for AI-enhanced development workflows. You get access to:

1. **Documentation Context** - UMH, PostgreSQL, and Redpanda docs via MCP
2. **Live System Integration** - Node-RED and Grafana via local MCP servers  
3. **Intelligent Development** - AI understands UMH patterns and best practices
4. **Rapid Prototyping** - Quickly test flows, dashboards, and integrations

## Quick Setup

### 1. Install Claude Code

```bash
# Install Claude Code CLI
pip install claude-code

# Or use your preferred AI assistant with MCP support
```

### 2. Add Documentation MCP Servers (User-Scoped)

These provide context about UMH, PostgreSQL, and Redpanda for all your projects:

```bash
# UMH Documentation
claude mcp add --transport http --scope user gitbook https://docs.umh.app/~gitbook/mcp

# PostgreSQL & TimescaleDB Documentation  
claude mcp add --transport http --scope user postgres-docs https://mcp.tigerdata.com/docs

# Redpanda Documentation
claude mcp add --transport http --scope user redpanda https://docs.redpanda.com/mcp
```

### 3. Verify MCP Configuration

```bash
claude mcp list
```

Expected output:
```
gitbook: https://docs.umh.app/~gitbook/mcp (HTTP) - ✓ Connected
postgres-docs: https://mcp.tigerdata.com/docs (HTTP) - ✓ Connected  
redpanda: https://docs.redpanda.com/mcp (HTTP) - ✓ Connected
```

### 4. Start UMH Stack with MCP Addon

```bash
# Navigate to repo
cd /path/to/LVE-UMH-CORE

# Start full stack with AI integration
docker compose -f docker-compose.yaml \
  -f examples/historian/docker-compose.historian.yaml \
  -f examples/mcp/docker-compose.mcp.yaml up -d
```

### 5. Connect to Local MCP Servers (Optional)

For live system access, add local MCP servers to your AI client:

```bash
# Node-RED MCP (flow development assistance)
claude mcp add --transport http --scope user umh-nodered http://localhost:3001

# Grafana MCP (dashboard assistance)  
claude mcp add --transport http --scope user umh-grafana http://localhost:3002
```

## Development Workflows

### 🔄 **Data Flow Development**

**Scenario**: Create a new data bridge for sensor data processing

**AI Prompts**:
```
"I need to create a data bridge that reads temperature sensor data from MQTT topic 
'sensors/temperature' and stores it in TimescaleDB. Use the existing UMH patterns."

"Show me how to configure continuous aggregates for hourly temperature averages 
in TimescaleDB."

"Create a Node-RED flow that processes this sensor data and publishes alerts 
when temperature exceeds thresholds."
```

**What the AI knows**:
- UMH documentation patterns and best practices
- TimescaleDB schema design and optimization  
- Redpanda/Kafka configuration for data bridges
- Your existing bridge configurations in `examples/databridges/flows/`

### 📊 **Dashboard Development**

**Scenario**: Build production monitoring dashboards

**AI Prompts**:
```
"Create a Grafana dashboard showing OEE metrics from the ERP data in TimescaleDB. 
Use the existing datasource configuration."

"Help me write a PostgreSQL query to calculate machine downtime from state changes 
in the tag_string table."

"Add alerting rules for when production efficiency drops below 80%."
```

**What the AI knows**:
- Grafana configuration and best practices
- TimescaleDB query optimization for time-series data
- Your existing database schema from `configs/timescaledb-init/`
- Pre-configured datasource settings

### 🏗️ **Infrastructure Management**

**Scenario**: Optimize and troubleshoot the stack

**AI Prompts**:
```
"Analyze the docker-compose configuration and suggest performance improvements 
for high-volume data ingestion."

"Help me configure retention policies for the TimescaleDB hypertables to 
manage disk usage."

"Debug why my MQTT messages aren't reaching the Unified Namespace."
```

**What the AI knows**:
- Docker networking and volume management
- PostgreSQL/TimescaleDB performance tuning
- UMH Core architecture and message flow patterns
- Your specific network configuration from `docs/networking.md`

### 🔧 **Integration Development**

**Scenario**: Add new systems and protocols

**AI Prompts**:
```
"I need to integrate a Siemens S7 PLC. Show me how to create a protocol converter 
configuration for UMH Core."

"Add an OPC-UA bridge that maps tag hierarchies to the Unified Namespace structure."

"Create a webhook endpoint that receives ERP events and triggers data processing flows."
```

**What the AI knows**:
- UMH protocol converter patterns
- Industrial protocol specifications and mappings
- REST API and webhook implementation patterns
- Your existing integration examples

## Advanced MCP Usage

### Live System Querying

With local MCP servers running, you can query your live system:

```bash
# Query current Node-RED flows
"What Node-RED flows are currently deployed and what do they do?"

# Analyze Grafana dashboards  
"What dashboards exist in Grafana and what data sources do they use?"

# Check database state
"Show me the current asset hierarchy in TimescaleDB."
```

### Real-Time Development

Make changes and get immediate feedback:

```bash
# Deploy a new flow
"Create and deploy a Node-RED flow that monitors MQTT queue depths and 
sends alerts when they exceed 1000 messages."

# Update dashboards
"Add a new panel to the Production Overview dashboard showing real-time 
energy consumption trends."

# Test data flows  
"Send test data through the temperature monitoring flow and verify 
it appears correctly in both TimescaleDB and the Grafana dashboard."
```

## Best Practices for AI-Assisted Development

### 1. **Provide Context in Prompts**

❌ **Vague**: "Create a dashboard"
✅ **Specific**: "Create a Grafana dashboard using the pre-configured TimescaleDB datasource that shows machine temperature trends from the tag table, grouped by asset_id"

### 2. **Reference Existing Patterns**

❌ **Generic**: "How do I connect to Kafka?"
✅ **Pattern-Aware**: "Following the pattern in `examples/databridges/flows/historian.yaml`, how do I create a new bridge that reads from a different MQTT topic?"

### 3. **Leverage Documentation Context**

The AI has access to comprehensive documentation. Ask questions like:
- "What's the recommended way to structure asset hierarchies in UMH?"
- "How do I optimize TimescaleDB for high-frequency sensor data?"  
- "What are Redpanda's best practices for topic configuration in industrial settings?"

### 4. **Use the Repository Structure**

The AI understands the repo layout. Reference specific files:
- "Update the nginx configuration in `configs/nginx.conf` to handle larger webhook payloads"
- "Modify the TimescaleDB init scripts in `configs/timescaledb-init/` to add new hypertables"

## Troubleshooting AI Development

### MCP Connection Issues

```bash
# Check MCP server health
curl http://localhost:3001/health  # Node-RED MCP
curl http://localhost:3002/health  # Grafana MCP

# Restart MCP servers
docker compose -f examples/mcp/docker-compose.mcp.yaml restart

# Check Claude Code MCP status
claude mcp list
```

### Context Limitations

If the AI seems to lack context:

1. **Verify MCP servers are connected**:
   ```bash
   claude mcp list | grep "Connected"
   ```

2. **Provide explicit file references**:
   ```
   "Looking at the configuration in configs/grafana/provisioning/datasources/datasources.yaml, 
   how should I modify the connection settings?"
   ```

3. **Reference documentation explicitly**:
   ```
   "According to the UMH documentation, what's the recommended approach for..."
   ```

## Development Workflow Examples

### End-to-End Feature Development

**Goal**: Add predictive maintenance alerting

**Steps with AI assistance**:

1. **Data Pipeline**:
   ```
   "Create a data bridge that collects vibration sensor data and calculates 
   rolling averages using the UMH patterns in examples/databridges/flows/"
   ```

2. **Data Storage**:
   ```
   "Design TimescaleDB schema optimizations for storing high-frequency 
   vibration data with proper compression and retention policies."
   ```

3. **Analytics Flow**:
   ```
   "Build a Node-RED flow that analyzes vibration trends and triggers 
   maintenance alerts using the existing MQTT infrastructure."
   ```

4. **Visualization**:
   ```
   "Create Grafana dashboards showing vibration trends, maintenance schedules, 
   and alert status using the pre-configured TimescaleDB datasource."
   ```

5. **Integration Testing**:
   ```
   "Help me test this end-to-end by sending simulated vibration data and 
   verifying it flows through to the dashboard correctly."
   ```

### Performance Optimization

**Goal**: Optimize for 10,000+ sensors

**AI-Assisted Analysis**:

```
"Analyze my current docker-compose configuration and TimescaleDB settings. 
Suggest optimizations for handling 10,000 sensors sending data every 5 seconds."

"Review the data bridge configurations and suggest batching/buffering 
improvements for high-throughput scenarios."

"Recommend Grafana query optimizations and dashboard design patterns 
for large-scale time-series data visualization."
```

## Security Considerations

### MCP Server Access

- **Local MCP servers** (Node-RED/Grafana) are only accessible from your development machine
- **Documentation MCP servers** are read-only and don't access your local data
- **Network isolation** follows existing UMH security patterns

### Production Usage

For production deployments:

1. **Disable local MCP servers**:
   ```bash
   # Don't include MCP addon in production
   docker compose -f docker-compose.yaml -f examples/historian/docker-compose.historian.yaml up -d
   ```

2. **Use documentation MCP only**:
   ```bash
   # Keep only docs access
   claude mcp remove umh-nodered
   claude mcp remove umh-grafana
   ```

3. **Secure credentials**: Never commit `.env` files or share MCP endpoints externally

## See Also

- [MCP Addon Documentation](../examples/mcp/README.md) - Local MCP server setup
- [Networking Guide](networking.md) - UMH network architecture
- [Operations Guide](operations.md) - Deployment and management
- [Integration Patterns](integration-patterns.md) - Data flow design patterns
- [UMH Official Docs](https://umh.docs.umh.app/) - Complete UMH documentation
- [Claude Code Documentation](https://docs.anthropic.com/en/docs/claude-code) - AI development workflows