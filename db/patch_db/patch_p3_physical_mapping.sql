-- ============================================================
-- OSA / ISA — PATCH P3 PHYSICAL MAPPING
-- Objectif : mapper les quick wins PRES + PTRA et créer rf.indicator_nature
-- ============================================================

BEGIN;

CREATE TABLE IF NOT EXISTS rf.indicator_nature (
    indicator_code       VARCHAR(30) PRIMARY KEY REFERENCES rf.indicators(code),
    nature_code          VARCHAR(30) NOT NULL,
    confidence_policy    VARCHAR(30) NOT NULL,
    physical_weight      NUMERIC(4,2) DEFAULT 0.50 CHECK (physical_weight >= 0 AND physical_weight <= 1),
    imputation_allowed   BOOLEAN DEFAULT TRUE,
    exclusion_threshold  NUMERIC(4,2) DEFAULT 0.40 CHECK (exclusion_threshold >= 0 AND exclusion_threshold <= 1),
    notes                TEXT,
    created_at           TIMESTAMP DEFAULT NOW(),
    updated_at           TIMESTAMP DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_indicator_nature_nature ON rf.indicator_nature(nature_code);
CREATE INDEX IF NOT EXISTS idx_indicator_nature_policy ON rf.indicator_nature(confidence_policy);

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
    ('PRES_OIL_RENTS',        'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.40, 'Rentes pétrolières — WB WDI'),
    ('PRES_GAS_RENTS',        'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.40, 'Rentes gaz naturel — WB WDI'),
    ('PRES_ENRG_USE_CAP',     'PHYSICAL',   'STRICT',   0.85, FALSE, 0.60, 'Consommation énergie par habitant — donnée physique'),
    ('PRES_FOSSIL_RENTS_EIA', 'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.40, 'Rentes ressources naturelles / fossiles — proxy WB'),
    ('PRES_RENEW_SHARE_FEC',  'STRUCTURAL', 'MODERATE', 0.60, TRUE,  0.40, 'Renouvelables % consommation finale — WB / IEA proxy'),
    ('PRES_WATER_AGRI',       'PHYSICAL',   'STRICT',   0.80, FALSE, 0.60, 'Terres irriguées / eau agricole — FAO AQUASTAT / WB proxy'),
    ('PTRA_RD_PAVED',         'PHYSICAL',   'STRICT',   0.80, FALSE, 0.60, 'Routes pavées % — infrastructure physique'),
    ('PTRA_RD_DENSITY',       'PHYSICAL',   'STRICT',   0.80, FALSE, 0.60, 'Densité routière — infrastructure physique'),
    ('PTRA_LOG_LPI',          'COMPOSITE',  'FLEXIBLE', 0.40, TRUE,  0.30, 'LPI Banque mondiale — indice composite'),
    ('PTRA_RD_QUALITY',       'PERCEPTION', 'MANUAL',   0.35, TRUE,  0.25, 'Qualité des routes — WEF/GCI, rupture de série 2018')
ON CONFLICT (indicator_code)
DO UPDATE SET
    nature_code         = EXCLUDED.nature_code,
    confidence_policy   = EXCLUDED.confidence_policy,
    physical_weight     = EXCLUDED.physical_weight,
    imputation_allowed  = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes               = EXCLUDED.notes,
    updated_at          = NOW();

INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description)
VALUES
('WB',  'World Bank Open Data', 'https://api.worldbank.org/v2', 0.95, 'World Bank WDI API'),
('WEF', 'World Economic Forum', 'https://www.weforum.org', 0.75, 'WEF/GCI manual indicators')
ON CONFLICT (code)
DO UPDATE SET
    name = EXCLUDED.name,
    base_url = EXCLUDED.base_url,
    reliability_score = EXCLUDED.reliability_score,
    description = EXCLUDED.description;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'WB_COUNTRY_INDICATOR', 'World Bank country indicator API',
       'https://api.worldbank.org/v2/country/{country}/indicator/{indicator}',
       'json', 'Endpoint générique World Bank WDI par pays et indicateur'
FROM collect.data_providers
WHERE code = 'WB'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id,
       'WEF_GCI_MANUAL',
       'WEF GCI manual series',
       'manual://wef/gci',
       'csv',
       'Séries WEF/GCI à chargement manuel, notamment qualité des routes'
FROM collect.data_providers
WHERE code = 'WEF'
ON CONFLICT (endpoint_code) DO NOTHING;

WITH src AS (
    SELECT *
    FROM (VALUES
        ('PRES_OIL_RENTS',        'WB_COUNTRY_INDICATOR', 'NY.GDP.PETR.RT.ZS', 'WB WDI — Oil rents (% of GDP)', 90.00),
        ('PRES_GAS_RENTS',        'WB_COUNTRY_INDICATOR', 'NY.GDP.NGAS.RT.ZS', 'WB WDI — Natural gas rents (% of GDP)', 90.00),
        ('PRES_ENRG_USE_CAP',     'WB_COUNTRY_INDICATOR', 'EG.USE.PCAP.KG.OE', 'WB WDI — Energy use per capita (kg oil equivalent)', 85.00),
        ('PRES_FOSSIL_RENTS_EIA', 'WB_COUNTRY_INDICATOR', 'NY.GDP.TOTL.RT.ZS', 'WB WDI proxy — Total natural resources rents (% of GDP)', 85.00),
        ('PRES_RENEW_SHARE_FEC',  'WB_COUNTRY_INDICATOR', 'EG.FEC.RNEW.ZS',    'WB WDI / IEA proxy — Renewable energy consumption (% final energy)', 85.00),
        ('PRES_WATER_AGRI',       'WB_COUNTRY_INDICATOR', 'AG.LND.IRIG.AG.ZS', 'WB WDI proxy — Agricultural irrigated land (% agricultural land)', 75.00),
        ('PTRA_RD_PAVED',         'WB_COUNTRY_INDICATOR', 'IS.ROD.PAVE.ZS',    'WB WDI — Roads paved (% total roads)', 75.00),
        ('PTRA_RD_DENSITY',       'WB_COUNTRY_INDICATOR', 'IS.ROD.DNST.K2',    'WB WDI — Road density (km road per sq. km land area)', 75.00),
        ('PTRA_LOG_LPI',          'WB_COUNTRY_INDICATOR', 'LP.LPI.OVRL.XQ',    'WB LPI — Overall logistics performance index', 70.00),
        ('PTRA_RD_QUALITY',       'WEF_GCI_MANUAL',       'GCI_ROAD_QUALITY',  'WEF/GCI manual — Road quality score; rupture série 2018 à documenter', 60.00)
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
    source_notes          = EXCLUDED.source_notes,
    coverage_pct          = EXCLUDED.coverage_pct,
    last_verified         = CURRENT_DATE,
    is_active             = TRUE;

INSERT INTO collect.source_registry (source_id, name, organization, api_type, base_url, status, priority, reliability_score)
VALUES
('WB',  'World Bank Open Data', 'World Bank', 'REST',   'https://api.worldbank.org/v2', 'GO',    1, 0.95),
('WEF', 'World Economic Forum', 'WEF',        'MANUAL', 'https://www.weforum.org',      'PILOT', 4, 0.75)
ON CONFLICT (source_id)
DO UPDATE SET status = EXCLUDED.status, reliability_score = EXCLUDED.reliability_score, updated_at = NOW();

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('WB',  'PRES_OIL_RENTS',        'NY.GDP.PETR.RT.ZS', 'WB_COUNTRY_INDICATOR', NULL, 'percent_gdp', 'annual', 'GO', TRUE),
('WB',  'PRES_GAS_RENTS',        'NY.GDP.NGAS.RT.ZS', 'WB_COUNTRY_INDICATOR', NULL, 'percent_gdp', 'annual', 'GO', TRUE),
('WB',  'PRES_ENRG_USE_CAP',     'EG.USE.PCAP.KG.OE', 'WB_COUNTRY_INDICATOR', NULL, 'kg_oil_equiv_per_capita', 'annual', 'GO', TRUE),
('WB',  'PRES_FOSSIL_RENTS_EIA', 'NY.GDP.TOTL.RT.ZS', 'WB_COUNTRY_INDICATOR', 'EIA direct if available', 'percent_gdp', 'annual', 'GO', TRUE),
('WB',  'PRES_RENEW_SHARE_FEC',  'EG.FEC.RNEW.ZS',    'WB_COUNTRY_INDICATOR', 'IEA direct if subscribed', 'percent', 'annual', 'GO', TRUE),
('WB',  'PRES_WATER_AGRI',       'AG.LND.IRIG.AG.ZS', 'WB_COUNTRY_INDICATOR', 'FAO AQUASTAT primary if available', 'percent', 'annual', 'GO', TRUE),
('WB',  'PTRA_RD_PAVED',         'IS.ROD.PAVE.ZS',    'WB_COUNTRY_INDICATOR', NULL, 'percent', 'annual', 'GO', TRUE),
('WB',  'PTRA_RD_DENSITY',       'IS.ROD.DNST.K2',    'WB_COUNTRY_INDICATOR', NULL, 'km_per_km2', 'annual', 'GO', TRUE),
('WB',  'PTRA_LOG_LPI',          'LP.LPI.OVRL.XQ',    'WB_COUNTRY_INDICATOR', NULL, 'index', 'biennial/irregular', 'GO', TRUE),
('WEF', 'PTRA_RD_QUALITY',       'GCI_ROAD_QUALITY',  'WEF_GCI_MANUAL',       'Manual import required', 'score', 'annual/irregular', 'PILOT', TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code = EXCLUDED.osa_code,
    endpoint = EXCLUDED.endpoint,
    fallback = EXCLUDED.fallback,
    unit = EXCLUDED.unit,
    frequency = EXCLUDED.frequency,
    decision = EXCLUDED.decision,
    is_active = TRUE,
    updated_at = NOW();

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN (
        'PRES_OIL_RENTS','PRES_GAS_RENTS','PRES_ENRG_USE_CAP','PRES_FOSSIL_RENTS_EIA','PRES_RENEW_SHARE_FEC','PRES_WATER_AGRI',
        'PTRA_RD_PAVED','PTRA_RD_DENSITY','PTRA_LOG_LPI','PTRA_RD_QUALITY'
    ) AND is_active = TRUE;
    RAISE NOTICE 'Mappings P3 PRES/PTRA actifs corrigés : % / 10', v_count;
END $$;

COMMIT;
