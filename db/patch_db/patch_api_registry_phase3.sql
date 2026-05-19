-- ============================================================
-- OSA Observatory — patch_api_registry_phase3.sql
-- Sprint 8 — Mai 2026
--
-- Enregistrement endpoints API Phase 3 (cartographie complète) :
--   /api/v2/decision/intervention-matrix  (+ /{iso3}) EXPERT
--   /api/v2/early-warning/annual-summary  (+ /{iso3}) PUBLIC
--
-- Complète la cartographie API initiée en Sprint 6.
-- Idempotent — peut être rejoué.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. mg.publication_registry
-- ------------------------------------------------------------

INSERT INTO mg.publication_registry (
    dataset_code, dataset_label, dataset_family,
    source_view, target_view, access_class,
    publication_status, release_code, public_api_path, notes
)
SELECT * FROM (VALUES
    ('INTERVENTION_MATRIX', 'ISA Intervention Decision Matrix — Expert Level', 'DECISION',
     'ma.v_isa_intervention_decision_matrix', 'ma.v_isa_intervention_decision_matrix',
     'EXPERT', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE',
     '/api/v2/decision/intervention-matrix',
     'Expert-level decision matrix. Crosses opportunities, costs, feasibility. Sprint 8.'),
    ('EW_ANNUAL_SUMMARY', 'ISA Early Warning Annual Summary by Country', 'EARLY_WARNING',
     'ma.v_isa_early_warning_country_year', 'ma.v_isa_early_warning_country_year',
     'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE',
     '/api/v2/early-warning/annual-summary',
     'Annual aggregate of early warning alerts per country. Sprint 8.')
) AS v(dataset_code, dataset_label, dataset_family, source_view, target_view,
       access_class, publication_status, release_code, public_api_path, notes)
WHERE NOT EXISTS (SELECT 1 FROM mg.publication_registry pr WHERE pr.dataset_code = v.dataset_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 2. mg.api_contract_registry
-- ------------------------------------------------------------

INSERT INTO mg.api_contract_registry (
    endpoint_code, api_version, http_method, api_path, source_view,
    access_class, auth_required, contract_status, breaking_change,
    release_code, response_contract_note
)
SELECT * FROM (VALUES
    ('V2_DECISION_MATRIX',       'v2','GET','/api/v2/decision/intervention-matrix',        'ma.v_isa_intervention_decision_matrix', 'EXPERT', TRUE, 'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Expert intervention matrix all countries. Sprint 8.'),
    ('V2_DECISION_MATRIX_ISO3',  'v2','GET','/api/v2/decision/intervention-matrix/{iso3}', 'ma.v_isa_intervention_decision_matrix', 'EXPERT', TRUE, 'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Expert intervention matrix single country. Sprint 8.'),
    ('V2_EW_ANNUAL_SUMMARY',     'v2','GET','/api/v2/early-warning/annual-summary',        'ma.v_isa_early_warning_country_year',  'PUBLIC',FALSE, 'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Annual EW summary all countries. Sprint 8.'),
    ('V2_EW_ANNUAL_SUMMARY_ISO3','v2','GET','/api/v2/early-warning/annual-summary/{iso3}', 'ma.v_isa_early_warning_country_year',  'PUBLIC',FALSE, 'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Annual EW summary single country. Sprint 8.')
) AS v(endpoint_code,api_version,http_method,api_path,source_view,access_class,auth_required,contract_status,breaking_change,release_code,response_contract_note)
WHERE NOT EXISTS (SELECT 1 FROM mg.api_contract_registry a WHERE a.endpoint_code = v.endpoint_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. rf.isa_api_endpoint_registry
-- ------------------------------------------------------------

INSERT INTO rf.isa_api_endpoint_registry (
    endpoint_code, api_version, http_method, api_path, backing_view,
    access_class, auth_required, rate_limit_policy, monetization_class,
    certification_dependency, is_enabled, endpoint_note, updated_at
)
SELECT * FROM (VALUES
    ('V2_DECISION_MATRIX',       'v2','GET','/api/v2/decision/intervention-matrix',        'ma.v_isa_intervention_decision_matrix','EXPERT',TRUE, 'RESTRICTED','PREMIUM',    'CERTIFIED_OR_PROVISIONAL',TRUE,'Expert intervention matrix. Sprint 8.',NOW()),
    ('V2_DECISION_MATRIX_ISO3',  'v2','GET','/api/v2/decision/intervention-matrix/{iso3}', 'ma.v_isa_intervention_decision_matrix','EXPERT',TRUE, 'RESTRICTED','PREMIUM',    'CERTIFIED_OR_PROVISIONAL',TRUE,'Expert intervention matrix single country. Sprint 8.',NOW()),
    ('V2_EW_ANNUAL_SUMMARY',     'v2','GET','/api/v2/early-warning/annual-summary',        'ma.v_isa_early_warning_country_year',  'PUBLIC',FALSE,'STANDARD',  'OPEN_DATA',  'CERTIFIED_OR_PROVISIONAL',TRUE,'Annual EW summary. Sprint 8.',NOW()),
    ('V2_EW_ANNUAL_SUMMARY_ISO3','v2','GET','/api/v2/early-warning/annual-summary/{iso3}', 'ma.v_isa_early_warning_country_year',  'PUBLIC',FALSE,'STANDARD',  'OPEN_DATA',  'CERTIFIED_OR_PROVISIONAL',TRUE,'Annual EW summary single country. Sprint 8.',NOW())
) AS v(endpoint_code,api_version,http_method,api_path,backing_view,access_class,auth_required,rate_limit_policy,monetization_class,certification_dependency,is_enabled,endpoint_note,updated_at)
WHERE NOT EXISTS (SELECT 1 FROM rf.isa_api_endpoint_registry r WHERE r.endpoint_code = v.endpoint_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. Vérification finale
-- ------------------------------------------------------------

SELECT
    'mg.publication_registry'      AS registre, COUNT(*) AS total,
    SUM(CASE WHEN dataset_code IN ('INTERVENTION_MATRIX','EW_ANNUAL_SUMMARY') THEN 1 ELSE 0 END) AS phase3
FROM mg.publication_registry
UNION ALL
SELECT 'mg.api_contract_registry', COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_DECISION_MATRIX%' OR endpoint_code LIKE 'V2_EW_ANNUAL%' THEN 1 ELSE 0 END)
FROM mg.api_contract_registry
UNION ALL
SELECT 'rf.isa_api_endpoint_registry', COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_DECISION_MATRIX%' OR endpoint_code LIKE 'V2_EW_ANNUAL%' THEN 1 ELSE 0 END)
FROM rf.isa_api_endpoint_registry;

COMMIT;
