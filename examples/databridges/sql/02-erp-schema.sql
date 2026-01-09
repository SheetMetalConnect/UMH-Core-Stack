-- ==============================================================================
-- ERP Integration Schema for UMH Core
-- ==============================================================================
-- Run AFTER configs/timescaledb-init/01-init-schema.sql
--
-- Creates:
--   - get_asset_id() function (ISA-95 hierarchy → Core asset model)
--   - ERP sales order tables with history tracking
--
-- Usage:
--   docker exec -i timescaledb psql -U postgres -d umh_v2 < 02-erp-schema.sql
-- ==============================================================================

-- ==============================================================================
-- Asset ID Lookup Function
-- ==============================================================================
-- Converts ISA-95 hierarchy to Core's (asset_name, location) model.
--
-- Produces SAME result as historian flow:
--   asset_name = most specific non-empty level
--   location   = dot-joined path ABOVE asset_name
--
-- Example:
--   get_asset_id('acme', 'chicago', 'packaging', 'line1', '', '')
--   → asset_name='line1', location='acme.chicago.packaging'
-- ==============================================================================

CREATE OR REPLACE FUNCTION get_asset_id(
    p_enterprise VARCHAR,
    p_site VARCHAR,
    p_area VARCHAR,
    p_line VARCHAR,
    p_workcell VARCHAR,
    p_origin_id VARCHAR
) RETURNS INTEGER AS $$
DECLARE
    v_asset_id INTEGER;
    v_asset_name VARCHAR;
    v_location VARCHAR;
    v_parts TEXT[];
BEGIN
    v_parts := ARRAY[]::TEXT[];
    IF p_enterprise IS NOT NULL AND p_enterprise != '' THEN
        v_parts := array_append(v_parts, p_enterprise);
    END IF;
    IF p_site IS NOT NULL AND p_site != '' THEN
        v_parts := array_append(v_parts, p_site);
    END IF;
    IF p_area IS NOT NULL AND p_area != '' THEN
        v_parts := array_append(v_parts, p_area);
    END IF;
    IF p_line IS NOT NULL AND p_line != '' THEN
        v_parts := array_append(v_parts, p_line);
    END IF;
    IF p_workcell IS NOT NULL AND p_workcell != '' THEN
        v_parts := array_append(v_parts, p_workcell);
    END IF;
    IF p_origin_id IS NOT NULL AND p_origin_id != '' THEN
        v_parts := array_append(v_parts, p_origin_id);
    END IF;
    
    IF array_length(v_parts, 1) IS NULL OR array_length(v_parts, 1) = 0 THEN
        RETURN NULL;
    ELSIF array_length(v_parts, 1) = 1 THEN
        v_asset_name := v_parts[1];
        v_location := '';
    ELSE
        v_asset_name := v_parts[array_length(v_parts, 1)];
        v_location := array_to_string(v_parts[1:array_length(v_parts, 1)-1], '.');
    END IF;
    
    INSERT INTO asset (asset_name, location)
    VALUES (v_asset_name, v_location)
    ON CONFLICT (asset_name) DO UPDATE SET 
        location = EXCLUDED.location,
        updated_at = NOW()
    RETURNING id INTO v_asset_id;
    
    RETURN v_asset_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_asset_id(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO kafkatopostgresqlv2;

-- ==============================================================================
-- Sales Order Tables
-- ==============================================================================

CREATE TABLE IF NOT EXISTS erp_sales_order (
    order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    customer_name TEXT,
    milestone TEXT,
    due_date TIMESTAMPTZ,
    order_date TIMESTAMPTZ,
    delivered_date TIMESTAMPTZ,
    status TEXT,
    change_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (order_id, asset_id)
);

CREATE TABLE IF NOT EXISTS erp_sales_order_history (
    history_id SERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL,
    customer_name TEXT,
    milestone TEXT,
    due_date TIMESTAMPTZ,
    order_date TIMESTAMPTZ,
    delivered_date TIMESTAMPTZ,
    status TEXT,
    change_type TEXT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    CONSTRAINT fk_sales_order_history
        FOREIGN KEY (order_id, asset_id)
        REFERENCES erp_sales_order (order_id, asset_id)
        ON DELETE CASCADE
);

-- ==============================================================================
-- Indexes
-- ==============================================================================

CREATE INDEX IF NOT EXISTS idx_erp_sales_order_status ON erp_sales_order (status);
CREATE INDEX IF NOT EXISTS idx_erp_sales_order_due ON erp_sales_order (due_date);
CREATE INDEX IF NOT EXISTS idx_erp_sales_order_history_recorded ON erp_sales_order_history (recorded_at DESC);

-- ==============================================================================
-- Permissions
-- ==============================================================================

GRANT SELECT, INSERT, UPDATE, DELETE ON erp_sales_order TO kafkatopostgresqlv2;
GRANT SELECT, INSERT ON erp_sales_order_history TO kafkatopostgresqlv2;
GRANT USAGE, SELECT ON SEQUENCE erp_sales_order_history_history_id_seq TO kafkatopostgresqlv2;

GRANT SELECT ON erp_sales_order, erp_sales_order_history TO grafanareader;

-- ==============================================================================
-- Auto-update trigger
-- ==============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_erp_sales_order_updated ON erp_sales_order;
CREATE TRIGGER tr_erp_sales_order_updated BEFORE UPDATE ON erp_sales_order
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();
