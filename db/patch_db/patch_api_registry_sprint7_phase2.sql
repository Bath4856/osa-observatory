-- ============================================================
-- OSA Observatory — patch_api_registry_sprint7_phase2.sql
-- Sprint 7 — Mai 2026
--
-- Enregistrement des endpoints API Phase 2 :
--   /api/v2/decision/priorities       (+ /{iso3})
--   /api/v2/sovereignty/readiness
--   /api/v2/early-warning/fragility   (+ /{iso3})
--   /api/v2/scenarios/country         (+ /{iso3})
--
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
    ('DECISION_PRIORITIES', 'ISA Sovereign Decision Priorities',          'DECISION',      'ma.v_isa_decision_priority_engine',    'ma.v_isa_decision_priority_engine',    'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/decision/priorities',       'Decision priorities by country/pillar. Sprint 7.'),
    ('SOVEREIGNTY_READINESS','ISA Sovereignty Readiness — Pillar Aggregate','SOVEREIGNTY', 'ma.v_isa_sovereignty_readiness',       'ma.v_isa_sovereignty_readiness',       'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/sovereignty/readiness',     'Sovereignty readiness aggregate. No country/year filter. Sprint 7.'),
    ('FRAGILITY_WARNING',    'ISA Structural Fragility Warning Signal',    'EARLY_WARNING', 'ma.v_isa_fragility_warning_engine',    'ma.v_isa_fragility_warning_engine',    'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/early-warning/fragility',   'Structural fragility signal. Methodology note required. Sprint 7.'),
    ('SCENARIOS_P7H',        'ISA P7H Scenario Simulations by Country',   'SCENARIOS',     'ma.v_isa_scenario_country_year',       'ma.v_isa_scenario_country_year',       'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/scenarios/country',         'P7H scenario simulations. Sprint 7.')
) AS v(dataset_code, dataset_label, dataset_family, source_view, target_view, access_class, publication_status, release_code, public_api_path, notes)
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
    ('V2_DECISION_PRIORITIES',       'v2','GET','/api/v2/decision/priorities',              'ma.v_isa_decision_priority_engine', 'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Decision priorities all countries. Sprint 7.'),
    ('V2_DECISION_PRIORITIES_ISO3',  'v2','GET','/api/v2/decision/priorities/{iso3}',       'ma.v_isa_decision_priority_engine', 'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Decision priorities single country. Sprint 7.'),
    ('V2_SOVEREIGNTY_READINESS',     'v2','GET','/api/v2/sovereignty/readiness',            'ma.v_isa_sovereignty_readiness',    'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Sovereignty readiness aggregate. Sprint 7.'),
    ('V2_EW_FRAGILITY',              'v2','GET','/api/v2/early-warning/fragility',          'ma.v_isa_fragility_warning_engine', 'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Fragility warning all countries. Sprint 7.'),
    ('V2_EW_FRAGILITY_ISO3',         'v2','GET','/api/v2/early-warning/fragility/{iso3}',   'ma.v_isa_fragility_warning_engine', 'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Fragility warning single country. Sprint 7.'),
    ('V2_SCENARIOS_COUNTRY',         'v2','GET','/api/v2/scenarios/country',                'ma.v_isa_scenario_country_year',    'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7H scenarios all countries. Sprint 7.'),
    ('V2_SCENARIOS_COUNTRY_ISO3',    'v2','GET','/api/v2/scenarios/country/{iso3}',         'ma.v_isa_scenario_country_year',    'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','P7H scenarios single country. Sprint 7.')
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
    ('V2_DECISION_PRIORITIES',      'v2','GET','/api/v2/decision/priorities',            'ma.v_isa_decision_priority_engine', 'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Decision priorities all countries. Sprint 7.',NOW()),
    ('V2_DECISION_PRIORITIES_ISO3', 'v2','GET','/api/v2/decision/priorities/{iso3}',     'ma.v_isa_decision_priority_engine', 'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Decision priorities single country. Sprint 7.',NOW()),
    ('V2_SOVEREIGNTY_READINESS',    'v2','GET','/api/v2/sovereignty/readiness',          'ma.v_isa_sovereignty_readiness',    'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Sovereignty readiness aggregate. Sprint 7.',NOW()),
    ('V2_EW_FRAGILITY',             'v2','GET','/api/v2/early-warning/fragility',        'ma.v_isa_fragility_warning_engine', 'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Fragility warning all countries. Sprint 7.',NOW()),
    ('V2_EW_FRAGILITY_ISO3',        'v2','GET','/api/v2/early-warning/fragility/{iso3}', 'ma.v_isa_fragility_warning_engine', 'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Fragility warning single country. Sprint 7.',NOW()),
    ('V2_SCENARIOS_COUNTRY',        'v2','GET','/api/v2/scenarios/country',              'ma.v_isa_scenario_country_year',    'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'P7H scenarios all countries. Sprint 7.',NOW()),
    ('V2_SCENARIOS_COUNTRY_ISO3',   'v2','GET','/api/v2/scenarios/country/{iso3}',       'ma.v_isa_scenario_country_year',    'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'P7H scenarios single country. Sprint 7.',NOW())
) AS v(endpoint_code,api_version,http_method,api_path,backing_view,access_class,auth_required,rate_limit_policy,monetization_class,certification_dependency,is_enabled,endpoint_note,updated_at)
WHERE NOT EXISTS (SELECT 1 FROM rf.isa_api_endpoint_registry r WHERE r.endpoint_code = v.endpoint_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. Vérification finale
-- ------------------------------------------------------------

SELECT
    'mg.publication_registry'      AS registre, COUNT(*) AS total,
    SUM(CASE WHEN dataset_code IN ('DECISION_PRIORITIES','SOVEREIGNTY_READINESS','FRAGILITY_WARNING','SCENARIOS_P7H') THEN 1 ELSE 0 END) AS phase2
FROM mg.publication_registry
UNION ALL
SELECT 'mg.api_contract_registry', COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_DECISION%' OR endpoint_code LIKE 'V2_SOVEREIGNTY_READINESS%' OR endpoint_code LIKE 'V2_EW_FRAGILITY%' OR endpoint_code LIKE 'V2_SCENARIOS%' THEN 1 ELSE 0 END)
FROM mg.api_contract_registry
UNION ALL
SELECT 'rf.isa_api_endpoint_registry', COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_DECISION%' OR endpoint_code = 'V2_SOVEREIGNTY_READINESS' OR endpoint_code LIKE 'V2_EW_FRAGILITY%' OR endpoint_code LIKE 'V2_SCENARIOS%' THEN 1 ELSE 0 END)
FROM rf.isa_api_endpoint_registry;

COMMIT;
