-- ============================================================
-- OSA / ISA — PATCH P1 INDICATOR SOURCE FIXES
-- Corrige les mappings P1 en échec API
-- ============================================================

BEGIN;

-- 1) Providers complémentaires
INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description)
VALUES
('IRENA', 'IRENA Renewable Capacity Statistics', 'https://www.irena.org/Data', 0.88, 'Données capacité renouvelable — CSV/API selon disponibilité')
ON CONFLICT (code) DO NOTHING;

-- 2) Endpoints complémentaires
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'IRENA_RENEW_CAP_CSV',
       'IRENA — Renewable capacity CSV',
       'https://www.irena.org/Data/Downloads/IRENASTAT',
       'csv',
       'Capacité électrique renouvelable — téléchargement / extraction CSV'
FROM collect.data_providers
WHERE code = 'IRENA'
ON CONFLICT (endpoint_code) DO NOTHING;

-- 3) Correction / insertion mappings P1
WITH src AS (
    SELECT *
    FROM (VALUES
        -- HTTP 400 corrigé : chômage WB WDI
        ('ECO_UNE',                  'WB_COUNTRY_INDICATOR',      'SL.UEM.TOTL.ZS',     'WB WDI — Unemployment, total (% of total labor force)', 90.00),

        -- HTTP 404 corrigés : indicateurs eau WB WDI
        ('PRES_WATER_FRESH',         'WB_COUNTRY_INDICATOR',      'ER.H2O.INTR.PC',     'WB WDI — Renewable internal freshwater resources per capita', 85.00),
        ('PRES_WATER_WITHDRAWAL',    'WB_COUNTRY_INDICATOR',      'ER.H2O.FWTL.ZS',     'WB WDI — Annual freshwater withdrawals, total (% internal resources)', 85.00),

        -- Timeout corrigé : éducation supérieure WB WDI
        ('PNUM_TERTIARY_ENROLL',     'WB_COUNTRY_INDICATOR',      'SE.TER.ENRR',        'WB WDI — School enrollment, tertiary (% gross)', 85.00),

        -- 404 IRENA : bascule vers endpoint IRENA CSV
        ('PRES_RENEW_CAP_IRENA',     'IRENA_RENEW_CAP_CSV',       'RENEW_CAP_MW',       'IRENA — Renewable electricity capacity, MW / share computed', 70.00),

        -- Timeout port : proxy WB LSCI
        ('PTRA_PORT_CONNECT',        'WB_COUNTRY_INDICATOR',      'IS.SHP.GCNW.XQ',     'WB WDI — Liner shipping connectivity index', 85.00)
    ) AS t(indicator_code, endpoint_code, source_indicator_code, source_notes, coverage_pct)
),
resolved AS (
    SELECT
        s.indicator_code,
        pe.id AS endpoint_id,
        s.source_indicator_code,
        s.source_notes,
        s.coverage_pct
    FROM src s
    JOIN rf.indicators i
        ON i.code = s.indicator_code
    JOIN collect.provider_endpoints pe
        ON pe.endpoint_code = s.endpoint_code
)
INSERT INTO collect.indicator_source
    (indicator_code, endpoint_id, source_indicator_code, source_notes, coverage_pct, last_verified, is_active)
SELECT
    indicator_code,
    endpoint_id,
    source_indicator_code,
    source_notes,
    coverage_pct,
    CURRENT_DATE,
    TRUE
FROM resolved
ON CONFLICT (indicator_code, endpoint_id)
DO UPDATE SET
    source_indicator_code = EXCLUDED.source_indicator_code,
    source_notes          = EXCLUDED.source_notes,
    coverage_pct          = EXCLUDED.coverage_pct,
    last_verified         = CURRENT_DATE,
    is_active             = TRUE;

-- 4) Registry P1 : inscrire ces corrections comme GO/PILOT
INSERT INTO collect.source_registry (source_id, name, organization, api_type, base_url, status, priority, reliability_score)
VALUES
('WB',    'World Bank Open Data', 'World Bank', 'REST', 'https://api.worldbank.org/v2', 'GO', 1, 0.95),
('IRENA', 'IRENA Data',           'IRENA',      'CSV',  'https://www.irena.org/Data',  'PILOT', 3, 0.88)
ON CONFLICT (source_id) DO UPDATE SET
    status = EXCLUDED.status,
    reliability_score = EXCLUDED.reliability_score,
    updated_at = now();

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('WB',    'ECO_UNE',               'SL.UEM.TOTL.ZS', 'WB_COUNTRY_INDICATOR', NULL, 'percent', 'annual', 'GO', TRUE),
('WB',    'PRES_WATER_FRESH',      'ER.H2O.INTR.PC', 'WB_COUNTRY_INDICATOR', NULL, 'm3_per_capita', 'annual', 'GO', TRUE),
('WB',    'PRES_WATER_WITHDRAWAL', 'ER.H2O.FWTL.ZS', 'WB_COUNTRY_INDICATOR', NULL, 'percent', 'annual', 'GO', TRUE),
('WB',    'PNUM_TERTIARY_ENROLL',  'SE.TER.ENRR',    'WB_COUNTRY_INDICATOR', NULL, 'percent', 'annual', 'GO', TRUE),
('IRENA', 'PRES_RENEW_CAP_IRENA',  'RENEW_CAP_MW',   'IRENA_RENEW_CAP_CSV',  'WB EG.ELC.RNEW.ZS proxy if unavailable', 'MW/share', 'annual', 'PILOT', TRUE),
('WB',    'PTRA_PORT_CONNECT',     'IS.SHP.GCNW.XQ', 'WB_COUNTRY_INDICATOR', 'UNCTAD LSCI if WB unavailable', 'index', 'annual', 'GO', TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    fallback   = EXCLUDED.fallback,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = now();

-- 5) Contrôle
DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM collect.indicator_source cs
    JOIN rf.indicators i ON i.code = cs.indicator_code
    WHERE cs.indicator_code IN (
        'ECO_UNE',
        'PRES_WATER_FRESH',
        'PRES_WATER_WITHDRAWAL',
        'PNUM_TERTIARY_ENROLL',
        'PRES_RENEW_CAP_IRENA',
        'PTRA_PORT_CONNECT'
    )
    AND cs.is_active = TRUE;

    RAISE NOTICE 'Mappings P1 actifs corrigés : % / 6', v_count;
END $$;

COMMIT;