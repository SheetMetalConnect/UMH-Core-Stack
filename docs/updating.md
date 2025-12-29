# Updating

UMH Core updates follow the same pattern in Docker Compose as the standalone command:

1. `docker compose down`
2. `docker compose pull`
3. `docker compose up -d`

Notes:
- v0.44+ runs as non-root (UID 1000). If you are upgrading from an older version, fix the `/data` volume ownership before starting the new container.
- With `:latest` images, always run `docker compose pull` to fetch updates.
