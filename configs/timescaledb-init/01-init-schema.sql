-- ==============================================================================
-- UMH TimescaleDB Initialization Script
-- ==============================================================================
-- Creates users, schema, tables, and policies for UMH Core historian
-- Executed automatically on first container startup
--
-- NOTE: Role creation happens in 00-create-users.sh.

-- ==============================================================================
-- Enable TimescaleDB Extension
-- ==============================================================================
CREATE EXTENSION IF NOT EXISTS timescaledb;

-- ==============================================================================
-- Create Schema
-- ==============================================================================

-- Asset table: Metadata about devices/equipment
CREATE TABLE IF NOT EXISTS asset (
    id SERIAL PRIMARY KEY,
    asset_name VARCHAR(255) NOT NULL UNIQUE,
    location VARCHAR(500),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Tag hypertable: Numeric time-series data
CREATE TABLE IF NOT EXISTS tag (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value DOUBLE PRECISION,
    origin VARCHAR(255)
);

SELECT create_hypertable('tag', 'time', if_not_exists => TRUE);

-- Tag_string hypertable: Text/string time-series data
CREATE TABLE IF NOT EXISTS tag_string (
    time TIMESTAMPTZ NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    tag_name VARCHAR(255) NOT NULL,
    value TEXT,
    origin VARCHAR(255)
);

SELECT create_hypertable('tag_string', 'time', if_not_exists => TRUE);

-- ==============================================================================
-- Create Indexes
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_tag_asset_id ON tag (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_asset_tag_time ON tag (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_tag_name_time ON tag (tag_name, time DESC);

CREATE INDEX IF NOT EXISTS idx_tag_string_asset_id ON tag_string (asset_id, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_asset_tag_time ON tag_string (asset_id, tag_name, time DESC);
CREATE INDEX IF NOT EXISTS idx_tag_string_tag_name_time ON tag_string (tag_name, time DESC);

-- ==============================================================================
-- Grant Permissions
-- ==============================================================================

GRANT CONNECT ON DATABASE umh_v2 TO kafkatopostgresqlv2;
GRANT USAGE ON SCHEMA public TO kafkatopostgresqlv2;
GRANT SELECT, INSERT, UPDATE ON asset TO kafkatopostgresqlv2;
GRANT SELECT, INSERT ON tag TO kafkatopostgresqlv2;
GRANT SELECT, INSERT ON tag_string TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE asset_id_seq TO kafkatopostgresqlv2;

GRANT CONNECT ON DATABASE umh_v2 TO grafanareader;
GRANT USAGE ON SCHEMA public TO grafanareader;
GRANT SELECT ON asset TO grafanareader;
GRANT SELECT ON tag TO grafanareader;
GRANT SELECT ON tag_string TO grafanareader;

-- ==============================================================================
-- Compression Policy
-- ==============================================================================

ALTER TABLE tag SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'asset_id,tag_name',
    timescaledb.compress_orderby = 'time DESC'
);

ALTER TABLE tag_string SET (
    timescaledb.compress,
    timescaledb.compress_segmentby = 'asset_id,tag_name',
    timescaledb.compress_orderby = 'time DESC'
);

SELECT add_compression_policy('tag', INTERVAL '7 days', if_not_exists => TRUE);
SELECT add_compression_policy('tag_string', INTERVAL '7 days', if_not_exists => TRUE);

-- ==============================================================================
-- Create NocoDB Schema
-- ==============================================================================
-- NocoDB will create its own tables, but we prepare the environment
CREATE SCHEMA IF NOT EXISTS nocodb;
