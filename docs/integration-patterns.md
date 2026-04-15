# Integration Patterns

Four patterns for getting external data (ERP, MES, web apps, webhooks) into UMH.

## Quick Comparison

| | A: On-Demand | B: ERP → UNS | C: Local DB | D: HTTP API |
|---|---|---|---|---|
| **Direction** | UMH pulls from ERP | ERP pushes to UNS | ERP syncs to DB | External POSTs to UMH |
| **Record volume** | High | Low (dozens) | High | Any |
| **Latency** | ~100-500ms | Instant read | Instant read | Instant write |
| **Offline** | No | Partial | Yes | No |
| **Complexity** | Low | Low | High (SQL) | Medium |
| **Sync response** | No | No | No | Yes (CRUD) |
| **This repo** | -- | -- | Implemented | Template |

---

## Pattern A: On-Demand Fetch

```
Trigger (scan/button) → Bridge → HTTP GET to ERP → UNS
```

Query ERP in real-time when an event occurs. UNS stays lean — only active records become topics.

**Best for:** ERP has a usable API, too many records to pre-load, latency acceptable.

---

## Pattern B: ERP Publishes to UNS

```
ERP (CDC/webhook/polling) → Bridge → UNS Topics → Consumers
```

ERP data pushed into UNS proactively. Each record becomes a topic.

**Best for:** Limited active records, ERP supports webhooks/CDC, multiple consumers need same data.

---

## Pattern C: Local Database Cache

```
ERP (batch/CDC) → Dataflow → TimescaleDB (schema you control)
                                    ↑
Shopfloor Event → UNS → Consumer ──┘ (enrich via SQL join)
```

ERP data synced to local database. Events flow through UNS. Consumers join event data with master data at query time.

**Best for:** ERP has no real-time API, complex queries needed, thousands of records, offline resilience.

**This repo implements this pattern** with deduplication flows (`erp_process.yaml`) and persistence flows (`erp_to_timescale.yaml`). See [flow templates](../examples/databridges/README.md).

### Topic Convention

```
umh.v1.{location}._entity.process    ← Incoming from ERP
umh.v1.{location}._entity.create     ← New record (after dedup)
umh.v1.{location}._entity.update     ← Changed fields
umh.v1.{location}._entity.duplicate  ← No change (dropped)
umh.v1.{location}._entity.delete     ← Removal
```

---

## Pattern D: HTTP API Inside UMH Core

```
External System ──POST──► NGINX ──► UMH Core (http_server) ──► UNS / DB
```

Create REST API endpoints directly inside UMH Core using Benthos `http_server` input. No separate backend needed — each endpoint is a dataflow listening on its own port, with NGINX routing external traffic.

**Best for:** Receiving webhooks, rapid prototyping, simple CRUD APIs, web app integrations.

### D1: Webhook → UNS (fire-and-forget)

Receive HTTP POST, transform, publish to UNS. No response body.

```yaml
input:
  http_server:
    address: 0.0.0.0:8090
    path: /api/v1/orders
    allowed_verbs: [POST]
pipeline:
  processors:
    - bloblang: |
        meta umh_topic = "umh.v1.mycompany.factory1._erp.orders"
        root.orderId = this.data.id
        root.status = this.event_type
output:
  uns: {}
```

### D2: HTTP → Direct SQL (no UNS)

Write directly to TimescaleDB. Good for updates that don't need event distribution.

```yaml
input:
  http_server:
    address: 0.0.0.0:8091
    path: /api/v1/stop-reason
    allowed_verbs: [POST]
output:
  sql_raw:
    driver: postgres
    dsn: ${DB_DSN}
    query: UPDATE machine_stops SET stop_reason_id = $1 WHERE id = $2
    args_mapping: "[this.reason_id, this.stop_id]"
```

### D3: Full CRUD API (sync response)

Handle POST/PUT/DELETE with JSON responses. Use `sync_response` for request-reply.

```yaml
input:
  http_server:
    address: 0.0.0.0:8092
    path: /api/v1/stop-reasons
    allowed_verbs: [POST, PUT, DELETE]
    sync_response:
      headers:
        Content-Type: application/json
pipeline:
  processors:
    - switch:
        - check: meta("http_server_verb") == "POST"
          processors:
            - sql_raw:
                query: INSERT INTO stop_reasons (name, category) VALUES ($1, $2) RETURNING *
                args_mapping: "[this.name, this.category]"
        - check: meta("http_server_verb") == "DELETE"
          processors:
            - sql_raw:
                query: DELETE FROM stop_reasons WHERE id = $1 RETURNING id
                args_mapping: "[this.id]"
output:
  sync_response: {}
```

### NGINX Routing

Each `http_server` binds to a unique port. NGINX gives them clean external URLs:

```nginx
location /api/v1/stop-reason  { proxy_pass http://umh-core:8091; }
location /api/v1/stop-reasons { proxy_pass http://umh-core:8092; }
location /webhook/            { proxy_pass http://umh-core:8040;  }
```

---

## Key Insight

The UNS is an event backbone, not a database. Publish state changes (order created, status changed), store master data where it can be queried efficiently. Mix patterns as needed — Pattern D for receiving, Pattern C for persistence.

## See Also

- [Data Modeling](data-modeling.md) — `_raw` vs data contracts
- [Historian](historian.md) — TimescaleDB schema and setup
- [Deployment Lessons](deployment-lessons.md) — DSN config, permissions
- [Flow Templates](../examples/databridges/README.md) — ERP dedup + persistence templates
