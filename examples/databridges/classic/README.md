# Classic Bridges (Reference)

These are the original UMH Classic (Kubernetes) flows for reference. For UMH Core, use the flows in `../flows/`.

## Key Differences: Classic → Core

| Aspect | Classic | Core |
|--------|---------|------|
| Input | `kafka_franz` | `uns:` |
| Output | `kafka_franz` | `uns: {}` |
| Topic metadata | `meta("kafka_topic")` | `meta("umh_topic")` |
| Wrapper | Bare Benthos config | `dataFlow:` or `protocolConverter:` |
| DB connection | k8s service DNS | `pgbouncer:5432` |
