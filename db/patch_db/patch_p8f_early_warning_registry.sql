-- ============================================================
-- OSA / ISA — P8F Early Warning Registry Patch
-- Sprint 5 — Mai 2026
--
-- Enregistre P7I-AMAR et P7I-AMAR-GENECO dans le registre
-- legacy rf.isa_api_endpoint_registry (P8F / API v1 gateway).
--
-- Complément de patch_p8v2_early_warning_registry.sql
-- qui couvre mg.api_contract_registry (v2).
--
-- Prérequis : patch_p8f_api_registry.sql doit avoir été exécuté.
-- Aucune vue modifiée. Aucun score recalculé.
-- ============================================================

BEGIN;

INSERT INTO rf.isa_api_endpoint_registry (
    endpoint_code,
    api_version,
    http_method,
    api_path,
    backing_view,
    access_class,
    auth_required,
    rate_limit_policy,
    monetization_class,
    certification_dependency,
    is_enabled,
    endpoint_note
)
VALUES

-- ── AMAR — Civilian Protection Risk ──────────────────────────
(
    'EW_CIVILIAN_PROTECTION',
    'v2', 'GET',
    '/api/v2/early-warning/civilian-protection',
    'mg.v_public_p7i_amar_alerts',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR civilian protection risk — all countries. '
        || 'Params: year, band, limit. '
        || 'Early-warning signal only. Not a legal qualification.'
),
(
    'EW_CIVILIAN_PROTECTION_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/civilian-protection/{iso3}',
    'mg.v_public_p7i_amar_alerts',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR civilian protection risk — single country, history 2010–2024.'
),

-- ── GENECO — Conflict Economy Exposure ───────────────────────
(
    'EW_CONFLICT_ECONOMY',
    'v2', 'GET',
    '/api/v2/early-warning/conflict-economy',
    'mg.v_public_p7i_amar_geneco_alerts',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR-GENECO conflict-economy exposure — all countries. '
        || 'Params: year, band, limit. '
        || 'Exposure signal only. Not legal attribution.'
),
(
    'EW_CONFLICT_ECONOMY_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/conflict-economy/{iso3}',
    'mg.v_public_p7i_amar_geneco_alerts',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR-GENECO conflict-economy exposure — single country, history 2010–2024.'
),

-- ── Composite AMAR + GENECO ───────────────────────────────────
(
    'EW_COMPOSITE',
    'v2', 'GET',
    '/api/v2/early-warning/composite',
    'ma.v_p7i_amar_composite_dashboard',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR composite — AMAR (70%) + GENECO (30%) — all countries. '
        || 'Params: year, band, limit.'
),
(
    'EW_COMPOSITE_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/composite/{iso3}',
    'ma.v_p7i_amar_composite_dashboard',
    'PUBLIC', FALSE,
    'STANDARD', 'OPEN_DATA', 'NONE',
    TRUE,
    'P7I-AMAR composite — single country, history 2010–2024.'
)

ON CONFLICT (endpoint_code) DO UPDATE SET
    api_version              = EXCLUDED.api_version,
    http_method              = EXCLUDED.http_method,
    api_path                 = EXCLUDED.api_path,
    backing_view             = EXCLUDED.backing_view,
    access_class             = EXCLUDED.access_class,
    auth_required            = EXCLUDED.auth_required,
    rate_limit_policy        = EXCLUDED.rate_limit_policy,
    monetization_class       = EXCLUDED.monetization_class,
    certification_dependency = EXCLUDED.certification_dependency,
    is_enabled               = EXCLUDED.is_enabled,
    endpoint_note            = EXCLUDED.endpoint_note,
    updated_at               = NOW();

-- ------------------------------------------------------------
-- Vérification : état complet des deux registres
-- ------------------------------------------------------------

DO $$
BEGIN
    RAISE NOTICE 'rf.isa_api_endpoint_registry total : %',
        (SELECT COUNT(*) FROM rf.isa_api_endpoint_registry);
    RAISE NOTICE 'rf.isa_api_endpoint_registry Early Warning : %',
        (SELECT COUNT(*) FROM rf.isa_api_endpoint_registry
         WHERE endpoint_code LIKE 'EW_%');
END $$;

SELECT
    endpoint_code,
    api_version,
    api_path,
    access_class,
    is_enabled
FROM rf.isa_api_endpoint_registry
WHERE endpoint_code LIKE 'EW_%'
ORDER BY endpoint_code;

COMMIT;
