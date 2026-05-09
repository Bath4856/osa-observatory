-- ============================================================
-- OSA / ISA — P5A PMIL SECURITY
-- Correction des orphelins PMIL :
--   MIL_EXP
--   MIL_EXP_PCT
--   MIL_EXP_PC
--   MIL_CYB
--   PMIL_HOMICIDE_RATE
-- ============================================================

BEGIN;

-- ============================================================
-- 1. Providers nécessaires
-- ============================================================

INSERT INTO collect.data_providers
    (code, name, base_url, reliability_score, description)
VALUES
('WB',    'World Bank Open Data',        'https://api.worldbank.org/v2', 0.95, 'World Development Indicators'),
('ITU',   'International Telecommunication Union', 'https://www.itu.int', 0.88, 'Global Cybersecurity Index / ICT data'),
('OSA',   'OSA Computed Indicators',     'internal://osa/computed',     0.90, 'Indicateurs calculés internes OSA')
ON CONFLICT (code)
DO UPDATE SET
    name              = EXCLUDED.name,
    base_url          = EXCLUDED.base_url,
    reliability_score = EXCLUDED.reliability_score,
    description       = EXCLUDED.description,
    is_active         = TRUE;

-- ============================================================
-- 2. Source registry
-- ============================================================

INSERT INTO collect.source_registry
    (source_id, name, organization, api_type, base_url, status, priority, reliability_score)
VALUES
('WB',  'World Bank Open Data',        'World Bank', 'REST',     'https://api.worldbank.org/v2', 'GO',    1, 0.95),
('ITU', 'ITU Global Cybersecurity Index', 'ITU',     'MANUAL',   'https://www.itu.int',          'PILOT', 3, 0.88),
('OSA', 'OSA Computed Indicators',     'OSA Observatory', 'COMPUTED', 'internal://osa/computed', 'GO', 1, 0.90)
ON CONFLICT (source_id)
DO UPDATE SET
    name              = EXCLUDED.name,
    organization      = EXCLUDED.organization,
    api_type          = EXCLUDED.api_type,
    base_url          = EXCLUDED.base_url,
    status            = EXCLUDED.status,
    priority          = EXCLUDED.priority,
    reliability_score = EXCLUDED.reliability_score,
    is_active         = TRUE,
    updated_at        = NOW();

-- ============================================================
-- 3. Endpoints nécessaires
-- ============================================================

-- WB generic endpoint
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT
    id,
    'WB_COUNTRY_INDICATOR',
    'World Bank country indicator endpoint',
    'https://api.worldbank.org/v2/country/{country}/indicator/{indicator}',
    'json',
    'Endpoint générique World Bank WDI par pays et indicateur'
FROM collect.data_providers
WHERE code = 'WB'
ON CONFLICT (endpoint_code)
DO UPDATE SET
    name          = EXCLUDED.name,
    endpoint_url  = EXCLUDED.endpoint_url,
    output_format = EXCLUDED.output_format,
    description   = EXCLUDED.description,
    is_active     = TRUE;

-- ITU GCI manual endpoint
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT
    id,
    'ITU_GCI_MANUAL',
    'ITU Global Cybersecurity Index manual series',
    'manual://itu/gci',
    'xlsx',
    'Série ITU GCI à chargement manuel ou semi-automatique'
FROM collect.data_providers
WHERE code = 'ITU'
ON CONFLICT (endpoint_code)
DO UPDATE SET
    name          = EXCLUDED.name,
    endpoint_url  = EXCLUDED.endpoint_url,
    output_format = EXCLUDED.output_format,
    description   = EXCLUDED.description,
    is_active     = TRUE;

-- OSA computed endpoint
INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT
    id,
    'OSA_COMPUTED',
    'OSA computed indicators',
    'internal://osa/computed',
    'json',
    'Indicateurs calculés à partir de séries OSA existantes'
FROM collect.data_providers
WHERE code = 'OSA'
ON CONFLICT (endpoint_code)
DO UPDATE SET
    name          = EXCLUDED.name,
    endpoint_url  = EXCLUDED.endpoint_url,
    output_format = EXCLUDED.output_format,
    description   = EXCLUDED.description,
    is_active     = TRUE;

-- ============================================================
-- 4. Nature des indicateurs PMIL
-- ============================================================

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight,
     imputation_allowed, exclusion_threshold, notes)
VALUES
('MIL_EXP',             'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.45, 'Dépenses militaires — alias / indicateur calculé OSA'),
('MIL_EXP_PCT',         'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.45, 'Dépenses militaires en % du PIB — source WB/SIPRI'),
('MIL_EXP_PC',          'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.45, 'Dépenses militaires par habitant — calcul OSA'),
('MIL_CYB',             'COMPOSITE',  'FLEXIBLE', 0.40, TRUE,  0.35, 'Cyberdéfense / cybersécurité — ITU GCI ou proxy OSA'),
('PMIL_HOMICIDE_RATE',  'EVENT',      'MODERATE', 0.50, TRUE,  0.40, 'Taux homicides — WB/UNODC')
ON CONFLICT (indicator_code)
DO UPDATE SET
    nature_code         = EXCLUDED.nature_code,
    confidence_policy   = EXCLUDED.confidence_policy,
    physical_weight     = EXCLUDED.physical_weight,
    imputation_allowed  = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes               = EXCLUDED.notes;

-- ============================================================
-- 5. Mapping opérationnel collect.indicator_source
-- ============================================================

WITH src AS (
    SELECT *
    FROM (VALUES
        -- vraie source WB/SIPRI
        ('MIL_EXP_PCT',        'WB_COUNTRY_INDICATOR', 'MS.MIL.XPND.GD.ZS',      'WB/SIPRI — Military expenditure (% of GDP)', 90.00),

        -- indicateurs calculés internes OSA
        ('MIL_EXP',            'OSA_COMPUTED',         'OSA_MIL_EXP_FROM_GDP_PCT', 'OSA — computed/alias from military expenditure % GDP', 80.00),
        ('MIL_EXP_PC',         'OSA_COMPUTED',         'OSA_MIL_EXP_PC_COMPUTED',  'OSA — computed from military expenditure and population', 80.00),

        -- cybersécurité
        ('MIL_CYB',            'ITU_GCI_MANUAL',       'GCI_CYBERSECURITY',        'ITU GCI — manual/semi-automatic source', 70.00),

        -- homicide
        ('PMIL_HOMICIDE_RATE', 'WB_COUNTRY_INDICATOR', 'VC.IHR.PSRC.P5',           'WB/UNODC — Intentional homicides per 100,000 people', 85.00)
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

-- ============================================================
-- 6. Source registry indicators
-- Important : pas de doublon (source_id, source_code)
-- ============================================================

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('WB',  'MIL_EXP_PCT',        'MS.MIL.XPND.GD.ZS',        'WB_COUNTRY_INDICATOR', 'SIPRI primary', 'percent_gdp', 'annual', 'GO', TRUE),
('OSA', 'MIL_EXP',            'OSA_MIL_EXP_FROM_GDP_PCT', 'OSA_COMPUTED',         'Alias/computed from military expenditure % GDP', 'index', 'annual', 'GO', TRUE),
('OSA', 'MIL_EXP_PC',         'OSA_MIL_EXP_PC_COMPUTED',  'OSA_COMPUTED',         'Computed from military expenditure and population', 'usd_per_capita', 'annual', 'GO', TRUE),
('ITU', 'MIL_CYB',            'GCI_CYBERSECURITY',        'ITU_GCI_MANUAL',       'ITU Global Cybersecurity Index manual/API', 'index', 'periodic', 'PILOT', TRUE),
('WB',  'PMIL_HOMICIDE_RATE', 'VC.IHR.PSRC.P5',           'WB_COUNTRY_INDICATOR', 'UNODC primary', 'per_100k', 'annual', 'GO', TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code   = EXCLUDED.osa_code,
    endpoint   = EXCLUDED.endpoint,
    fallback   = EXCLUDED.fallback,
    unit       = EXCLUDED.unit,
    frequency  = EXCLUDED.frequency,
    decision   = EXCLUDED.decision,
    is_active  = TRUE,
    updated_at = NOW();

-- ============================================================
-- 7. Contrôle final
-- ============================================================

DO $$
DECLARE
    v_count INT;
BEGIN
    SELECT COUNT(*)
    INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN (
        'MIL_EXP',
        'MIL_EXP_PCT',
        'MIL_EXP_PC',
        'MIL_CYB',
        'PMIL_HOMICIDE_RATE'
    )
    AND is_active = TRUE;

    RAISE NOTICE 'P5A PMIL security mappings actifs : % / 5', v_count;
END $$;

COMMIT;