#!/usr/bin/env bash
set -euo pipefail

writer_password="${HISTORIAN_WRITER_PASSWORD:-changeme}"
reader_password="${HISTORIAN_READER_PASSWORD:-changeme}"

psql -v ON_ERROR_STOP=1 \
  --username "${POSTGRES_USER:-postgres}" \
  --dbname "${POSTGRES_DB:-umh_v2}" <<EOSQL
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
EOSQL
