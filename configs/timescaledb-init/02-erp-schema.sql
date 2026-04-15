-- ==============================================================================
-- ERP Integration Schema for UMH Core
-- ==============================================================================
-- Runs after 01-init-schema.sql (auto-executed on first startup).
--
-- Creates:
--   - get_asset_id() function (ISA-95 hierarchy → Core asset model)
--   - ERP sales order tables with history tracking
--   - ERP sales item tables with history tracking
--   - ERP work order tables with history tracking
--   - updated_at trigger function
--
-- The get_asset_id() function is used by the historian flow to resolve
-- asset IDs inline — no branch/sql_select needed.
-- ==============================================================================

-- ==============================================================================
-- Helper: Auto-update trigger
-- ==============================================================================

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ==============================================================================
-- Asset ID Lookup Function
-- ==============================================================================
-- Converts ISA-95 hierarchy to Core's asset model.
--
-- Produces:
--   asset_name = most specific non-empty level
--   location   = dot-joined path above asset_name
--   enterprise/site/area/line/workcell/origin_id populated for uniqueness
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

    INSERT INTO asset (
        asset_name,
        location,
        enterprise,
        site,
        area,
        line,
        workcell,
        origin_id
    )
    VALUES (
        v_asset_name,
        v_location,
        COALESCE(p_enterprise, ''),
        COALESCE(p_site, ''),
        COALESCE(p_area, ''),
        COALESCE(p_line, ''),
        COALESCE(p_workcell, ''),
        COALESCE(p_origin_id, '')
    )
    ON CONFLICT (asset_name) DO UPDATE SET
        location = EXCLUDED.location,
        enterprise = EXCLUDED.enterprise,
        site = EXCLUDED.site,
        area = EXCLUDED.area,
        line = EXCLUDED.line,
        workcell = EXCLUDED.workcell,
        origin_id = EXCLUDED.origin_id,
        updated_at = NOW()
    RETURNING id INTO v_asset_id;

    RETURN v_asset_id;
END;
$$ LANGUAGE plpgsql;

GRANT EXECUTE ON FUNCTION get_asset_id(VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR, VARCHAR) TO kafkatopostgresqlv2;

-- ==============================================================================
-- Sales Orders
-- ==============================================================================

CREATE TABLE IF NOT EXISTS erp_sales_orders (
    order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    customer_name TEXT,
    customer_code TEXT,
    description TEXT,
    status TEXT,
    due_date TIMESTAMPTZ,
    order_date TIMESTAMPTZ,
    timestamp_ms TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (order_id, asset_id)
);

CREATE TABLE IF NOT EXISTS erp_sales_orders_history (
    history_id BIGSERIAL PRIMARY KEY,
    order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL,
    customer_name TEXT,
    customer_code TEXT,
    description TEXT,
    status TEXT,
    due_date TIMESTAMPTZ,
    order_date TIMESTAMPTZ,
    timestamp_ms TIMESTAMPTZ,
    change_type TEXT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS tr_erp_sales_orders_updated ON erp_sales_orders;
CREATE TRIGGER tr_erp_sales_orders_updated BEFORE UPDATE ON erp_sales_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_erp_sales_orders_status ON erp_sales_orders (status);
CREATE INDEX IF NOT EXISTS idx_erp_sales_orders_due ON erp_sales_orders (due_date);
CREATE INDEX IF NOT EXISTS idx_erp_sales_orders_history_recorded ON erp_sales_orders_history (recorded_at DESC);

-- ==============================================================================
-- Sales Items (line items within a sales order)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS erp_sales_items (
    item_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    order_id TEXT,
    article_code TEXT,
    description TEXT,
    due_date TIMESTAMPTZ,
    quantity NUMERIC,
    quantity_delivered NUMERIC,
    status TEXT,
    timestamp_ms TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (item_id, asset_id)
);

CREATE TABLE IF NOT EXISTS erp_sales_items_history (
    history_id BIGSERIAL PRIMARY KEY,
    item_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL,
    order_id TEXT,
    article_code TEXT,
    description TEXT,
    due_date TIMESTAMPTZ,
    quantity NUMERIC,
    quantity_delivered NUMERIC,
    status TEXT,
    timestamp_ms TIMESTAMPTZ,
    change_type TEXT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS tr_erp_sales_items_updated ON erp_sales_items;
CREATE TRIGGER tr_erp_sales_items_updated BEFORE UPDATE ON erp_sales_items
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_erp_sales_items_order ON erp_sales_items (order_id);
CREATE INDEX IF NOT EXISTS idx_erp_sales_items_status ON erp_sales_items (status);
CREATE INDEX IF NOT EXISTS idx_erp_sales_items_history_recorded ON erp_sales_items_history (recorded_at DESC);

-- ==============================================================================
-- Work Orders (production orders linked to sales items)
-- ==============================================================================

CREATE TABLE IF NOT EXISTS erp_work_orders (
    work_order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL REFERENCES asset(id) ON DELETE CASCADE,
    item_id TEXT,
    due_date TIMESTAMPTZ,
    article_code TEXT,
    description TEXT,
    quantity_planned NUMERIC,
    quantity_produced NUMERIC,
    status TEXT,
    timestamp_ms TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    change_type TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (work_order_id, asset_id)
);

CREATE TABLE IF NOT EXISTS erp_work_orders_history (
    history_id BIGSERIAL PRIMARY KEY,
    work_order_id TEXT NOT NULL,
    asset_id INTEGER NOT NULL,
    item_id TEXT,
    due_date TIMESTAMPTZ,
    article_code TEXT,
    description TEXT,
    quantity_planned NUMERIC,
    quantity_produced NUMERIC,
    status TEXT,
    timestamp_ms TIMESTAMPTZ,
    change_type TEXT NOT NULL,
    recorded_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

DROP TRIGGER IF EXISTS tr_erp_work_orders_updated ON erp_work_orders;
CREATE TRIGGER tr_erp_work_orders_updated BEFORE UPDATE ON erp_work_orders
    FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE INDEX IF NOT EXISTS idx_erp_work_orders_item ON erp_work_orders (item_id);
CREATE INDEX IF NOT EXISTS idx_erp_work_orders_status ON erp_work_orders (status);
CREATE INDEX IF NOT EXISTS idx_erp_work_orders_due ON erp_work_orders (due_date);
CREATE INDEX IF NOT EXISTS idx_erp_work_orders_history_recorded ON erp_work_orders_history (recorded_at DESC);
