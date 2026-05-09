BEGIN;

INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description)
VALUES
('OSA', 'OSA Observatory internal computed/geospatial', 'internal://osa', 0.80,
 'Données calculées ou consolidées par OSA à partir de sources tierces')
ON CONFLICT (code) DO NOTHING;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'OSA_PMIN_GEOSPATIAL', 'OSA PMIN geospatial computed layer',
       'internal://osa/pmin-geospatial', 'csv',
       'Données géospatiales PMIN consolidées : sites, coordonnées, potentiel'
FROM collect.data_providers
WHERE code = 'OSA'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('MIN_RES',        'STRUCTURAL', 'STRICT',   0.85, FALSE, 0.65, 'Réserves minières — données structurelles sensibles'),
('MIN_RAR',        'STRUCTURAL', 'STRICT',   0.85, FALSE, 0.65, 'Terres rares / minerais stratégiques'),
('MIN_GEO',        'STRUCTURAL', 'STRICT',   0.85, FALSE, 0.65, 'Réserves prouvées / potentiel géologique normé'),
('MIN_POT',        'STRUCTURAL', 'STRICT',   0.85, FALSE, 0.65, 'Potentiel géologique non exploité'),
('MIN_SITE_COUNT', 'GEO',        'MODERATE', 0.70, TRUE,  0.50, 'Densité des sites miniers actifs'),
('MIN_PMIN_SITE',  'GEO',        'MODERATE', 0.70, TRUE,  0.50, 'Score géospatial PMIN par site'),
('PGEO_MINE_COUNT','GEO',        'MODERATE', 0.60, TRUE,  0.50, 'Nombre de sites miniers recensés'),
('PGEO_MINE_COORD','GEO',        'MODERATE', 0.60, TRUE,  0.50, 'Qualité géolocalisation sites miniers')
ON CONFLICT (indicator_code) DO UPDATE SET
    nature_code = EXCLUDED.nature_code,
    confidence_policy = EXCLUDED.confidence_policy,
    physical_weight = EXCLUDED.physical_weight,
    imputation_allowed = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes = EXCLUDED.notes;

WITH src AS (
    SELECT * FROM (VALUES
        ('MIN_RES',         'USGS_MYB_MINERALS',    'mineral_reserves_value',   'USGS/OSA — valeur des réserves minières', 65.00),
        ('MIN_RAR',         'USGS_MYB_MINERALS',    'rare_earths_strategic',    'USGS/OSA — concentration terres rares et minerais stratégiques', 60.00),
        ('MIN_GEO',         'USGS_MYB_MINERALS',    'proved_reserves_index',    'USGS/OSA — réserves prouvées / indice norme', 60.00),
        ('MIN_POT',         'USGS_MYB_MINERALS',    'geological_potential',     'USGS/OSA — potentiel géologique non exploité', 60.00),
        ('MIN_SITE_COUNT',  'OSA_PMIN_GEOSPATIAL',  'active_mine_site_density', 'OSA geospatial — densité sites miniers actifs', 70.00),
        ('MIN_PMIN_SITE',   'OSA_PMIN_GEOSPATIAL',  'pmin_site_score',          'OSA geospatial — score PMIN par site', 70.00),
        ('PGEO_MINE_COUNT', 'OSA_PMIN_GEOSPATIAL',  'mine_site_count',          'OSA geospatial — nombre sites miniers', 70.00),
        ('PGEO_MINE_COORD', 'OSA_PMIN_GEOSPATIAL',  'mine_coord_quality',       'OSA geospatial — qualité géolocalisation', 70.00)
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

DO $$
DECLARE v_count INT;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM collect.indicator_source
    WHERE indicator_code IN (
        'MIN_RES','MIN_RAR','MIN_GEO','MIN_POT','MIN_SITE_COUNT','MIN_PMIN_SITE','PGEO_MINE_COUNT','PGEO_MINE_COORD'
    )
    AND is_active = TRUE;
    RAISE NOTICE 'P4B reserves/geospatial mappings actifs : % / 8', v_count;
END $$;

COMMIT;
