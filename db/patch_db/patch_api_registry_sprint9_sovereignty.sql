-- ============================================================
-- OSA Observatory — patch_api_registry_sprint9_sovereignty.sql
-- Sprint 9D — Mai 2026
-- ============================================================

BEGIN;

INSERT INTO rf.isa_api_endpoint_registry
    (endpoint_code, api_version, http_method, api_path,
     backing_view, access_class, auth_required, is_enabled, endpoint_note)
VALUES
    ('SOVEREIGNTY_FISCAL_MARGIN_ALL',   'v2', 'GET',
     '/api/v2/sovereignty/fiscal-margin',
     'ma.indicator_values[GEO_SOVEREIGN_MARGIN]',
     'PUBLIC', FALSE, TRUE,
     'Marge souveraineté fiscale tous pays — Doctrine OSA v1 — Sprint 9D'),
    ('SOVEREIGNTY_FISCAL_MARGIN_ISO3',  'v2', 'GET',
     '/api/v2/sovereignty/fiscal-margin/{iso3}',
     'ma.indicator_values[GEO_SOVEREIGN_MARGIN]',
     'PUBLIC', FALSE, TRUE,
     'Marge souveraineté fiscale pays unique — Doctrine OSA v1 — Sprint 9D')
ON CONFLICT (endpoint_code) DO UPDATE SET
    is_enabled    = TRUE,
    endpoint_note = EXCLUDED.endpoint_note,
    updated_at    = NOW();

DO $$
DECLARE v_total INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_total FROM rf.isa_api_endpoint_registry WHERE is_enabled = TRUE;
    RAISE NOTICE 'Total endpoints actifs : %', v_total;
END;
$$;

COMMIT;
