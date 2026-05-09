-- ============================================================
-- OSA / ISA — PATCH P5B PHUM STRUCTURAL
-- Objectif : éliminer les orphelins PHUM restants
-- ============================================================

BEGIN;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('HUM_POP', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Population active / structure démographique — WB'),
('HUM_FOO', 'STRUCTURAL', 'MODERATE', 0.50, TRUE, 0.45, 'Sécurité alimentaire — FAO/WB proxy'),
('HUM_DIG', 'STRUCTURAL', 'MODERATE', 0.45, TRUE, 0.40, 'Compétences numériques — WB/UNESCO/ITU proxy'),
('HUM_SOC', 'COMPOSITE',  'FLEXIBLE', 0.35, TRUE, 0.35, 'Cohésion sociale — composite OSA'),
('HUM_RES', 'COMPOSITE',  'FLEXIBLE', 0.35, TRUE, 0.35, 'Résilience sociale — composite OSA')
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
('FAO', 'FAOSTAT / FAO Data', 'FAO', 'REST/CSV', 'https://www.fao.org/faostat', 'GO', 2, 0.90),
('OSA', 'OSA Internal Composite', 'OSA Observatory', 'INTERNAL', 'internal://osa', 'GO', 1, 0.88)
ON CONFLICT (source_id) DO UPDATE SET
    status = EXCLUDED.status,
    reliability_score = EXCLUDED.reliability_score,
    updated_at = now();

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'OSA_COMPOSITE_INTERNAL', 'OSA internal composite', 'internal://osa/composite', 'csv', 'Composite interne OSA ou calcul analytique'
FROM collect.data_providers
WHERE code = 'OSA'
ON CONFLICT (endpoint_code) DO NOTHING;

WITH src AS (
    SELECT *
    FROM (VALUES
        ('HUM_POP', 'WB_COUNTRY_INDICATOR', 'SL.TLF.TOTL.IN', 'WB WDI — Labor force, total', 85.00),
        ('HUM_FOO', 'WB_COUNTRY_INDICATOR', 'SN.ITK.DEFC.ZS', 'WB WDI/FAO — Prevalence of undernourishment (%)', 80.00),
        ('HUM_DIG', 'WB_COUNTRY_INDICATOR', 'SE.ADT.LITR.ZS', 'WB WDI/UNESCO — Adult literacy proxy for digital skills', 70.00),
        ('HUM_SOC', 'OSA_COMPOSITE_INTERNAL', 'HUM_SOC_COMPOSITE', 'OSA composite — social cohesion', 70.00),
        ('HUM_RES', 'OSA_COMPOSITE_INTERNAL', 'HUM_RES_COMPOSITE', 'OSA composite — social resilience', 70.00)
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
('WB',  'HUM_POP', 'SL.TLF.TOTL.IN', 'WB_COUNTRY_INDICATOR', NULL, 'count', 'annual', 'GO', TRUE),
('WB',  'HUM_FOO', 'SN.ITK.DEFC.ZS', 'WB_COUNTRY_INDICATOR', 'FAO primary', 'percent', 'annual', 'GO', TRUE),
('WB',  'HUM_DIG', 'SE.ADT.LITR.ZS', 'WB_COUNTRY_INDICATOR', 'UNESCO/ITU proxy preferred when available', 'percent', 'annual', 'PILOT', TRUE),
('OSA', 'HUM_SOC', 'HUM_SOC_COMPOSITE', 'OSA_COMPOSITE_INTERNAL', NULL, 'score', 'annual', 'GO', TRUE),
('OSA', 'HUM_RES', 'HUM_RES_COMPOSITE', 'OSA_COMPOSITE_INTERNAL', NULL, 'score', 'annual', 'GO', TRUE)
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
    WHERE indicator_code IN ('HUM_POP','HUM_FOO','HUM_DIG','HUM_SOC','HUM_RES')
      AND is_active = TRUE;
    RAISE NOTICE 'P5B PHUM mappings actifs : % / 5', v_count;
END $$;

COMMIT;
