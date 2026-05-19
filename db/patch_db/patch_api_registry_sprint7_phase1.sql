-- ============================================================
-- OSA Observatory — patch_api_registry_sprint7_phase1.sql
-- Sprint 7 — Mai 2026
--
-- Enregistrement des 3 endpoints API Phase 1 dans les registres
-- officiels OSA :
--   mg.publication_registry
--   mg.api_contract_registry
--   rf.isa_api_endpoint_registry (P8F)
--
-- Endpoints :
--   GET /api/v2/sovereignty/swot          (+ /{iso3})
--   GET /api/v2/early-warning/escalation  (+ /{iso3})
--   GET /api/v2/early-warning/priority-queue
--
-- Idempotent — peut être rejoué.
-- ============================================================

BEGIN;

-- ------------------------------------------------------------
-- 1. mg.publication_registry
-- ------------------------------------------------------------

-- Vérifier les colonnes disponibles
DO $$
DECLARE
    v_col TEXT;
BEGIN
    SELECT column_name INTO v_col
    FROM information_schema.columns
    WHERE table_schema = 'mg'
      AND table_name   = 'publication_registry'
    LIMIT 1;
    IF v_col IS NULL THEN
        RAISE EXCEPTION 'mg.publication_registry introuvable';
    END IF;
END;
$$;

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
SELECT * FROM (VALUES
    ('SWOT_SIGNALS',    'ISA Sovereign SWOT Signals',               'SOVEREIGNTY',   'ma.v_isa_swot_signal_engine',        'ma.v_isa_swot_signal_engine',        'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/sovereignty/swot',             'F/O/F/M signals per pillar per country. Sprint 7.'),
    ('RISK_ESCALATION', 'ISA Sovereign Risk Escalation Signal',     'EARLY_WARNING', 'ma.v_isa_risk_escalation_engine',    'ma.v_isa_risk_escalation_engine',    'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/early-warning/escalation',     'Escalation trend signal. Methodology note required. Sprint 7.'),
    ('PRIORITY_QUEUE',  'ISA Sovereign Intervention Priority Queue','EARLY_WARNING', 'ma.v_isa_national_escalation_queue', 'ma.v_isa_national_escalation_queue', 'PUBLIC', 'P8V2_CANDIDATE', 'P8V2_2026_CANDIDATE', '/api/v2/early-warning/priority-queue', 'Priority queue by executive priority score. Sprint 7.')
) AS v(dataset_code, dataset_label, dataset_family, source_view, target_view, access_class, publication_status, release_code, public_api_path, notes)
WHERE NOT EXISTS (
    SELECT 1 FROM mg.publication_registry pr WHERE pr.dataset_code = v.dataset_code
)
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
    ('V2_SOVEREIGNTY_SWOT',      'v2','GET','/api/v2/sovereignty/swot',                'ma.v_isa_swot_signal_engine',        'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','SWOT signals all countries. Sprint 7.'),
    ('V2_SOVEREIGNTY_SWOT_ISO3', 'v2','GET','/api/v2/sovereignty/swot/{iso3}',         'ma.v_isa_swot_signal_engine',        'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','SWOT signals single country. Sprint 7.'),
    ('V2_EW_ESCALATION',         'v2','GET','/api/v2/early-warning/escalation',        'ma.v_isa_risk_escalation_engine',    'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Risk escalation all countries. Sprint 7.'),
    ('V2_EW_ESCALATION_ISO3',    'v2','GET','/api/v2/early-warning/escalation/{iso3}', 'ma.v_isa_risk_escalation_engine',    'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Risk escalation single country. Sprint 7.'),
    ('V2_EW_PRIORITY_QUEUE',     'v2','GET','/api/v2/early-warning/priority-queue',    'ma.v_isa_national_escalation_queue', 'PUBLIC',FALSE,'CANDIDATE',FALSE,'P8V2_2026_CANDIDATE','Intervention priority queue. Sprint 7.')
) AS v(endpoint_code,api_version,http_method,api_path,source_view,access_class,auth_required,contract_status,breaking_change,release_code,response_contract_note)
WHERE NOT EXISTS (SELECT 1 FROM mg.api_contract_registry a WHERE a.endpoint_code = v.endpoint_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 3. rf.isa_api_endpoint_registry (P8F)
-- ------------------------------------------------------------

INSERT INTO rf.isa_api_endpoint_registry (
    endpoint_code, api_version, http_method, api_path, backing_view,
    access_class, auth_required, rate_limit_policy, monetization_class,
    certification_dependency, is_enabled, endpoint_note, updated_at
)
SELECT * FROM (VALUES
    ('V2_SOVEREIGNTY_SWOT',      'v2','GET','/api/v2/sovereignty/swot',                'ma.v_isa_swot_signal_engine',        'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'SWOT signals all countries. Sprint 7.',NOW()),
    ('V2_SOVEREIGNTY_SWOT_ISO3', 'v2','GET','/api/v2/sovereignty/swot/{iso3}',         'ma.v_isa_swot_signal_engine',        'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'SWOT signals single country. Sprint 7.',NOW()),
    ('V2_EW_ESCALATION',         'v2','GET','/api/v2/early-warning/escalation',        'ma.v_isa_risk_escalation_engine',    'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Risk escalation all countries. Sprint 7.',NOW()),
    ('V2_EW_ESCALATION_ISO3',    'v2','GET','/api/v2/early-warning/escalation/{iso3}', 'ma.v_isa_risk_escalation_engine',    'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Risk escalation single country. Sprint 7.',NOW()),
    ('V2_EW_PRIORITY_QUEUE',     'v2','GET','/api/v2/early-warning/priority-queue',    'ma.v_isa_national_escalation_queue', 'PUBLIC',FALSE,'STANDARD','OPEN_DATA','CERTIFIED_OR_PROVISIONAL',TRUE,'Intervention priority queue. Sprint 7.',NOW())
) AS v(endpoint_code,api_version,http_method,api_path,backing_view,access_class,auth_required,rate_limit_policy,monetization_class,certification_dependency,is_enabled,endpoint_note,updated_at)
WHERE NOT EXISTS (SELECT 1 FROM rf.isa_api_endpoint_registry r WHERE r.endpoint_code = v.endpoint_code)
ON CONFLICT DO NOTHING;

-- ------------------------------------------------------------
-- 4. Vérification
-- ------------------------------------------------------------

SELECT
    'mg.publication_registry'  AS registre,
    COUNT(*) AS total,
    SUM(CASE WHEN dataset_code IN ('SWOT_SIGNALS','RISK_ESCALATION','PRIORITY_QUEUE') THEN 1 ELSE 0 END) AS sprint7
FROM mg.publication_registry

UNION ALL

SELECT
    'mg.api_contract_registry',
    COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_SOVEREIGNTY%' OR endpoint_code LIKE 'V2_EW_ESCALATION%' OR endpoint_code = 'V2_EW_PRIORITY_QUEUE' THEN 1 ELSE 0 END)
FROM mg.api_contract_registry

UNION ALL

SELECT
    'rf.isa_api_endpoint_registry',
    COUNT(*),
    SUM(CASE WHEN endpoint_code LIKE 'V2_SOVEREIGNTY%' OR endpoint_code LIKE 'V2_EW_ESCALATION%' OR endpoint_code = 'V2_EW_PRIORITY_QUEUE' THEN 1 ELSE 0 END)
FROM rf.isa_api_endpoint_registry;

COMMIT;
