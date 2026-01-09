# ERP Integration Patterns

Three patterns for integrating ERP/MES data into UMH.

The challenge: ERP holds master data (work orders, BOMs, inventory) that shopfloor systems need, but ERP systems are typically read-only from manufacturing perspective and may contain thousands of records.

## Pattern A: On-Demand Fetch

```
Trigger Event (scan/button) → Bridge → HTTP GET to ERP → UNS
```

Query ERP in real-time when an event occurs.

**When to use:**
- ERP has a usable API
- Too many records to pre-load (thousands)
- Only active/scanned orders need to be in UNS
- Latency ~100-500ms acceptable

**Trade-offs:**
- (+) UNS stays lean — only active records become topics
- (+) Always fetches current ERP state
- (-) Depends on ERP availability at query time
- (-) No offline capability

## Pattern B: ERP Publishes to UNS

```
ERP (CDC/webhook/polling) → Bridge → UNS Topics → Consumers query via GraphQL
```

ERP data pushed into UNS topics proactively. Each record becomes a topic.

**When to use:**
- Limited active records (dozens, not thousands)
- ERP supports change data capture or webhooks
- Multiple consumers need same records simultaneously
- Real-time sync critical

**Trade-offs:**
- (+) Data available instantly
- (+) Multiple consumers see same state
- (-) Topic explosion with many records
- (-) Stale data if sync fails

## Pattern C: Local Database Cache ← **This repo implements this**

```
ERP (batch/CDC) → Stand-alone Flow → Local DB (schema you control)
                                          ↑
Shopfloor Event → UNS → Consumer ─────────┘ (enrich via SQL join)
```

ERP data synced to local database. Events flow through UNS. Consumers join event data with master data.

**When to use:**
- ERP has no real-time API (file exports, RFC, BAPI)
- Complex queries needed (joins, filters, aggregations)
- Thousands of records
- Need offline resilience
- OEE, scan logs need a home anyway

**Trade-offs:**
- (+) Schema you control — add columns ERP doesn't have
- (+) Complex queries, historical analysis, reporting
- (+) Offline capable
- (+) Full history tracking for process mining
- (-) Additional infrastructure (PostgreSQL/TimescaleDB)
- (-) Sync lag — eventual consistency

## Comparison

| Aspect | A: On-Demand | B: ERP → UNS | C: Local DB |
|--------|--------------|--------------|-------------|
| Record volume | High (thousands) | Low (dozens) | High |
| ERP dependency | Per request | At sync time | At sync time |
| Latency | ~100-500ms | Instant read | Instant read |
| Offline | No | Partial | Yes |
| Query complexity | Single key | Single key | SQL joins |
| UNS topic count | Low | High | Low |
| History tracking | No | No | Yes |

## Pattern C Implementation in This Repo

### Flow Architecture

```
External MQTT
     │
     ▼ .process
┌────────────────────┐
│ mqtt_to_uns_bridge │
└─────────┬──────────┘
          ▼
       [UNS]
          │
          ▼
┌─────────────────────┐
│ sales_order_process │  ← Compare against DB
└─────────┬───────────┘
          │ .create / .update / .duplicate
          ▼
       [UNS]
          │
    ┌─────┴─────┐
    ▼           ▼
┌────────┐  ┌──────────────────┐
│ DB sink│  │ MQTT feedback    │
└────┬───┘  └──────────────────┘
     │
     ▼
┌─────────────────────────────┐
│ erp_sales_order (current)   │
│ erp_sales_order_history     │ ← Full audit trail
└─────────────────────────────┘
```

### What This Enables

1. **Event-driven architecture** — Every change is an event
2. **Deduplication** — Don't flood with unchanged data
3. **Full history** — Every state change recorded with timestamp
4. **Process mining** — Query historical state transitions
5. **Bidirectional sync** — Feedback to external systems

### Topic Convention

```
umh.v1.{location}._sales_order.process    ← Incoming from ERP
umh.v1.{location}._sales_order.create     ← New record
umh.v1.{location}._sales_order.update     ← Changed
umh.v1.{location}._sales_order.duplicate  ← No change
umh.v1.{location}._sales_order.delete     ← Removal
```

## Key Insight

The UNS is an event backbone, not a database. It excels at real-time distribution of state changes. Master data lookups and complex queries belong in a purpose-built data store.

Publish events (order started, status changed), store master data where it can be queried efficiently.
