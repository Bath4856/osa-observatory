-- ============================================================
-- OSA / ISA — P8 V2 Early Warning Registry Patch
-- Sprint 5 — Mai 2026 — CORRECTIF v2 (noms de colonnes vérifiés)
--
-- mg.publication_registry  : colonne "notes"
-- mg.api_contract_registry : colonne "response_contract_note"
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. mg.publication_registry — 3 datasets Early Warning
--    Colonnes : dataset_code, dataset_label, dataset_family,
--               source_view, target_view, access_class,
--               publication_status, release_code,
--               public_api_path, notes
-- ------------------------------------------------------------

INSERT INTO mg.publication_registry (
    dataset_code,
    dataset_label,
    dataset_family,
    source_view,
    target_view,
    access_class,
    publication_status,
    release_code,
    public_api_path,
    notes
)
VALUES

(
    'ISA_EARLY_WARNING_AMAR',
    'P7I-AMAR Civilian Protection Risk',
    'EARLY_WARNING',
    'mg.v_public_p7i_amar_alerts',
    'mg.v_public_p7i_amar_alerts',
    'PUBLIC',
    'P8V2_CANDIDATE',
    'P8V2_2026_CANDIDATE',
    '/api/v2/early-warning/civilian-protection',
    'P7I-AMAR atrocity precursor and civilian protection risk scores. '
        || '54 African countries, 2010–2024. '
        || 'Early-warning signal for prevention purposes only. '
        || 'Does not constitute a legal qualification of atrocity or genocide.'
),

(
    'ISA_EARLY_WARNING_GENECO',
    'P7I-AMAR-GENECO Conflict Economy Exposure',
    'EARLY_WARNING',
    'mg.v_public_p7i_amar_geneco_alerts',
    'mg.v_public_p7i_amar_geneco_alerts',
    'PUBLIC',
    'P8V2_CANDIDATE',
    'P8V2_2026_CANDIDATE',
    '/api/v2/early-warning/conflict-economy',
    'P7I-AMAR-GENECO conflict-economy exposure scores. '
        || '54 African countries, 2010–2024. '
        || 'Covers resource capture, logistics enabling, institutional capture, '
        || 'civilian exploitation, and narrative weaponization. '
        || 'Exposure signal only. Not legal attribution.'
),

(
    'ISA_EARLY_WARNING_COMPOSITE',
    'P7I-AMAR Composite Early Warning',
    'EARLY_WARNING',
    'ma.v_p7i_amar_composite_dashboard',
    'ma.v_p7i_amar_composite_dashboard',
    'PUBLIC',
    'P8V2_CANDIDATE',
    'P8V2_2026_CANDIDATE',
    '/api/v2/early-warning/composite',
    'Composite score combining P7I-AMAR (70%) and P7I-AMAR-GENECO (30%). '
        || 'Integrated sovereign risk signal for prevention purposes. '
        || 'Does not constitute a legal qualification.'
)

ON CONFLICT (dataset_code) DO UPDATE SET
    dataset_label      = EXCLUDED.dataset_label,
    dataset_family     = EXCLUDED.dataset_family,
    source_view        = EXCLUDED.source_view,
    target_view        = EXCLUDED.target_view,
    access_class       = EXCLUDED.access_class,
    publication_status = EXCLUDED.publication_status,
    public_api_path    = EXCLUDED.public_api_path,
    notes              = EXCLUDED.notes,
    updated_at         = NOW();

-- ------------------------------------------------------------
-- 2. mg.api_contract_registry — 6 endpoints Early Warning
--    Colonnes : endpoint_code, api_version, http_method,
--               api_path, source_view, access_class,
--               auth_required, contract_status, breaking_change,
--               release_code, response_contract_note
-- ------------------------------------------------------------

INSERT INTO mg.api_contract_registry (
    endpoint_code,
    api_version,
    http_method,
    api_path,
    source_view,
    access_class,
    auth_required,
    contract_status,
    breaking_change,
    release_code,
    response_contract_note
)
VALUES

(
    'V2_EW_CIVILIAN_PROTECTION',
    'v2', 'GET',
    '/api/v2/early-warning/civilian-protection',
    'mg.v_public_p7i_amar_alerts',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR civilian protection risk — all countries. '
        || 'Params: year, band, limit. '
        || 'Returns atrocity precursor scores with domain breakdown and methodology note.'
),
(
    'V2_EW_CIVILIAN_PROTECTION_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/civilian-protection/{iso3}',
    'mg.v_public_p7i_amar_alerts',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR civilian protection risk — single country, full history 2010–2024.'
),
(
    'V2_EW_CONFLICT_ECONOMY',
    'v2', 'GET',
    '/api/v2/early-warning/conflict-economy',
    'mg.v_public_p7i_amar_geneco_alerts',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR-GENECO conflict-economy exposure — all countries. '
        || 'Params: year, band, limit. '
        || 'Returns five-component exposure scores. Not legal attribution.'
),
(
    'V2_EW_CONFLICT_ECONOMY_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/conflict-economy/{iso3}',
    'mg.v_public_p7i_amar_geneco_alerts',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR-GENECO conflict-economy exposure — single country, full history.'
),
(
    'V2_EW_COMPOSITE',
    'v2', 'GET',
    '/api/v2/early-warning/composite',
    'ma.v_p7i_amar_composite_dashboard',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR composite score — AMAR (70%) + GENECO (30%) — all countries. '
        || 'Params: year, band, limit.'
),
(
    'V2_EW_COMPOSITE_ISO3',
    'v2', 'GET',
    '/api/v2/early-warning/composite/{iso3}',
    'ma.v_p7i_amar_composite_dashboard',
    'PUBLIC', FALSE, 'CANDIDATE', FALSE,
    'P8V2_2026_CANDIDATE',
    'P7I-AMAR composite score — single country, full history 2010–2024.'
)

ON CONFLICT (endpoint_code) DO UPDATE SET
    api_version            = EXCLUDED.api_version,
    http_method            = EXCLUDED.http_method,
    api_path               = EXCLUDED.api_path,
    source_view            = EXCLUDED.source_view,
    access_class           = EXCLUDED.access_class,
    auth_required          = EXCLUDED.auth_required,
    contract_status        = EXCLUDED.contract_status,
    breaking_change        = EXCLUDED.breaking_change,
    response_contract_note = EXCLUDED.response_contract_note,
    updated_at             = NOW();

-- ------------------------------------------------------------
-- 3. Vérification
-- ------------------------------------------------------------

SELECT
    'publication_registry'     AS registry,
    COUNT(*)                   AS total,
    COUNT(*) FILTER (WHERE dataset_family = 'EARLY_WARNING') AS early_warning
FROM mg.publication_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'

UNION ALL

SELECT
    'api_contract_registry'    AS registry,
    COUNT(*)                   AS total,
    COUNT(*) FILTER (WHERE endpoint_code LIKE 'V2_EW%') AS early_warning
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE';

COMMIT;
