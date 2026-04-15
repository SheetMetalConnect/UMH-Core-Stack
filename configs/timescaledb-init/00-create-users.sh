#!/usr/bin/env bash
set -euo pipefail

writer_password="${HISTORIAN_WRITER_PASSWORD:-changeme}"
reader_password="${HISTORIAN_READER_PASSWORD:-changeme}"

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER:-postgres}" \
  --dbname "${POSTGRES_DB:-umh}" <<EOSQL

-- Create users if not exist
DO \$\$
BEGIN
  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'kafkatopostgresqlv2') THEN
    CREATE ROLE kafkatopostgresqlv2 LOGIN PASSWORD '${writer_password}';
  ELSE
    ALTER ROLE kafkatopostgresqlv2 WITH PASSWORD '${writer_password}';
  END IF;

  IF NOT EXISTS (SELECT FROM pg_catalog.pg_roles WHERE rolname = 'grafanareader') THEN
    CREATE ROLE grafanareader LOGIN PASSWORD '${reader_password}';
  ELSE
    ALTER ROLE grafanareader WITH PASSWORD '${reader_password}';
  END IF;
END
\$\$;

-- Grant full permissions to writer (tables, sequences, schema)
GRANT USAGE, CREATE ON SCHEMA public TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO kafkatopostgresqlv2;
GRANT USAGE, SELECT, UPDATE ON ALL SEQUENCES IN SCHEMA public TO kafkatopostgresqlv2;

-- Set default privileges for future tables/sequences
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT, INSERT, UPDATE, DELETE ON TABLES TO kafkatopostgresqlv2;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT USAGE, SELECT, UPDATE ON SEQUENCES TO kafkatopostgresqlv2;

-- Grant read permissions to reader
GRANT USAGE ON SCHEMA public TO grafanareader;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO grafanareader;
ALTER DEFAULT PRIVILEGES IN SCHEMA public GRANT SELECT ON TABLES TO grafanareader;

EOSQL
