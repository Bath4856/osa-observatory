-- ============================================================
-- OSA / ISA — PATCH P5C HYBRIDS FINAL
-- Objectif : éliminer les derniers orphelins hybrides
-- ============================================================

BEGIN;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('ECO_AGR',       'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Sécurité alimentaire/agriculture — WB/FAO proxy'),
('NUM_CYB',       'COMPOSITE',  'FLEXIBLE', 0.35, TRUE, 0.35, 'Cybersécurité nationale — ITU GCI/OSA'),
('PTRA_PORT_CAP', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Capacité portuaire containers — WB/UNCTAD proxy')
ON CONFLICT (indicator_code)
DO UPDATE SET
    nature_code = EXCLUDED.nature_code,
    confidence_policy = EXCLUDED.confidence_policy,
    physical_weight = EXCLUDED.physical_weight,
    imputation_allowed = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes = EXCLUDED.notes;

INSERT INTO collect.source_registry (source_id, name, organization, api_type, base_url, status, priority, reliability_score)
VALUES
('WB', 'World Bank Open Data', 'World Bank', 'REST', 'https://api.worldbank.org/v2', 'GO', 1, 0.95),
('ITU', 'ITU Global Cybersecurity Index', 'ITU', 'MANUAL/CSV', 'https://www.itu.int', 'PILOT', 4, 0.82),
('UNCTAD', 'UNCTADstat', 'UNCTAD', 'CSV/API', 'https://unctadstat.unctad.org', 'PILOT', 4, 0.82)
ON CONFLICT (source_id) DO UPDATE SET
    status = EXCLUDED.status,
    reliability_score = EXCLUDED.reliability_score,
    updated_at = now();

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'UNCTAD_PORT_CAP_CSV', 'UNCTAD port capacity CSV/manual', 'https://unctadstat.unctad.org', 'csv', 'Capacité portuaire / conteneurs ; fallback WB shipping'
FROM collect.data_providers
WHERE code = 'UNCTAD'
ON CONFLICT (endpoint_code) DO NOTHING;

WITH src AS (
    SELECT *
    FROM (VALUES
        ('ECO_AGR',       'WB_COUNTRY_INDICATOR', 'AG.PRD.FOOD.XD', 'WB WDI — Food production index proxy', 80.00),
        ('NUM_CYB',       'ITU_GCI_MANUAL',       'GCI_CYBER',      'ITU GCI — national cybersecurity composite/manual', 70.00),
        ('PTRA_PORT_CAP', 'WB_COUNTRY_INDICATOR', 'IS.SHP.GOOD.TU', 'WB WDI — Container port traffic TEU proxy', 80.00)
    ) AS t(indicator_code, endpoint_code, source_indicator_code, source_notes, coverage_pct)
),
resolved AS (
    SELECT s.indicator_code, pe.id AS endpoint_id, s.source_indicator_code, s.source_notes, s.coverage_pct
    FROM src s
    JOIN rf.indicators i ON i.code = s.indicator_code
    JOIN collect.provider_endpoints pe ON pe.endpoint_code = s.endpoint_code
)
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, coverage_pct, last_verified, is_active)
SELECT indicator_code, endpoint_id, source_indicator_code, source_notes, coverage_pct, CURRENT_DATE, TRUE
FROM resolved
ON CONFLICT (indicator_code, endpoint_id)
DO UPDATE SET
    source_indicator_code = EXCLUDED.source_indicator_code,
    source_notes = EXCLUDED.source_notes,
    coverage_pct = EXCLUDED.coverage_pct,
    last_verified = CURRENT_DATE,
    is_active = TRUE;

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('WB',  'ECO_AGR',       'AG.PRD.FOOD.XD', 'WB_COUNTRY_INDICATOR', 'FAO primary recommended', 'index', 'annual', 'GO', TRUE),
('ITU', 'NUM_CYB',       'GCI_CYBER',      'ITU_GCI_MANUAL',       'OSA computed fallback', 'index', 'periodic', 'PILOT', TRUE),
('WB',  'PTRA_PORT_CAP', 'IS.SHP.GOOD.TU', 'WB_COUNTRY_INDICATOR', 'UNCTAD primary', 'TEU', 'annual', 'GO', TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code = EXCLUDED.osa_code,
    endpoint = EXCLUDED.endpoint,
    fallback = EXCLUDED.fallback,
    unit = EXCLUDED.unit,
    frequency = EXCLUDED.frequency,
    decision = EXCLUDED.decision,
    is_active = TRUE,
    updated_at = now();

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN ('ECO_AGR','NUM_CYB','PTRA_PORT_CAP')
      AND is_active = TRUE;
    RAISE NOTICE 'P5C hybrid mappings actifs : % / 3', v_count;
END $$;

COMMIT;
