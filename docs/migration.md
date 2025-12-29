# Migration to Client VM

When moving this stack to a client VM, treat it as a data + config migration:

1. Pin image tags for a consistent cutover (avoid `:latest` during the move).
2. Copy `.env` to the VM and set secrets appropriately.
3. Back up named volumes and restore them on the VM:
   - `umh-data`, `timescaledb-data`, `grafana-data`, `nodered-data`, `hivemq-data`, `portainer-data`
4. Start the stack on the VM with `docker compose up -d`.
5. Verify connectivity and only then switch over clients.

Notes:
- If the VM cannot reach `management.umh.app`, plan to manage UMH Core via `/data/config.yaml`.
- Review firewall rules and expose only required ports.
- Consider a reverse proxy with TLS for UI access.
