BEGIN;

INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description)
VALUES
('EITI', 'Extractive Industries Transparency Initiative', 'https://eiti.org', 0.80,
 'Gouvernance extractive, transparence et conformité'),
('COMTRADE', 'UN Comtrade', 'https://comtradeplus.un.org', 0.82,
 'Flux commerciaux internationaux par produits')
ON CONFLICT (code) DO NOTHING;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'COMTRADE_MINERALS', 'UN Comtrade minerals trade',
       'manual://comtrade/minerals', 'csv',
       'Flux commerciaux minéraux HS/SITC consolidés par OSA'
FROM collect.data_providers WHERE code = 'COMTRADE'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'EITI_COUNTRY_STATUS', 'EITI country status and extractive governance',
       'manual://eiti/country-status', 'csv',
       'Statut EITI, conformité, transparence extractive'
FROM collect.data_providers WHERE code = 'EITI'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('MIN_CRI',  'COMPOSITE',  'FLEXIBLE', 0.45, TRUE, 0.40, 'Indice criticité minérale stratégique'),
('MIN_DIV',  'COMPOSITE',  'FLEXIBLE', 0.45, TRUE, 0.40, 'Diversification minière'),
('MIN_TECH', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Niveau technologique minier'),
('MIN_CERT', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Conformité certifications'),
('MIN_ENV',  'COMPOSITE',  'MODERATE', 0.50, TRUE, 0.45, 'Impact environnemental minier')
ON CONFLICT (indicator_code) DO UPDATE SET
    nature_code = EXCLUDED.nature_code,
    confidence_policy = EXCLUDED.confidence_policy,
    physical_weight = EXCLUDED.physical_weight,
    imputation_allowed = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes = EXCLUDED.notes;

WITH src AS (
    SELECT * FROM (VALUES
        ('MIN_CRI',  'COMTRADE_MINERALS',  'critical_minerals_index', 'OSA/Comtrade/USGS — indice criticité', 65.00),
        ('MIN_DIV',  'COMTRADE_MINERALS',  'mining_diversification',  'OSA/Comtrade — diversification', 65.00),
        ('MIN_TECH', 'OSA_PMIN_GEOSPATIAL','mining_technology_level','OSA — niveau technologique', 60.00),
        ('MIN_CERT', 'EITI_COUNTRY_STATUS','mining_certification',   'EITI/OSA — certifications', 60.00),
        ('MIN_ENV',  'OSA_PMIN_GEOSPATIAL','mining_env_impact',      'OSA — impact environnemental', 60.00)
    ) AS t(indicator_code, endpoint_code, source_indicator_code, source_notes, coverage_pct)
),
resolved AS (
    SELECT s.indicator_code, pe.id AS endpoint_id, s.source_indicator_code, s.source_notes, s.coverage_pct
    FROM src s JOIN rf.indicators i ON i.code = s.indicator_code
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

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN ('MIN_CRI','MIN_DIV','MIN_TECH','MIN_CERT','MIN_ENV')
    AND is_active = TRUE;
    RAISE NOTICE 'P4C criticality/composites mappings actifs : % / 5', v_count;
END $$;

COMMIT;
