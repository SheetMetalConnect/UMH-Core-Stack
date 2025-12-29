# Security Notes

- Change default passwords before production use.
- PgBouncer is exposed on port 5432 for local access; do not expose it publicly.
- HiveMQ CE allows all clients by default - add authentication for production.
- Portainer has access to Docker socket - secure appropriately.
- NGINX is included by default; add TLS termination and auth for production.

## See Also

- [Networking](networking.md) - Port exposure and network isolation
- [Operations](operations.md) - Environment configuration
