BEGIN;

INSERT INTO collect.data_providers (code, name, base_url, reliability_score, description)
VALUES
('USGS', 'USGS Mineral Statistics and Information',
 'https://www.usgs.gov/centers/national-minerals-information-center', 0.92,
 'USGS — production minière physique, Mineral Yearbook / Mineral Commodity Summaries')
ON CONFLICT (code) DO UPDATE SET
    name = EXCLUDED.name,
    base_url = EXCLUDED.base_url,
    reliability_score = EXCLUDED.reliability_score,
    description = EXCLUDED.description;

INSERT INTO collect.provider_endpoints
    (provider_id, endpoint_code, name, endpoint_url, output_format, description)
SELECT id, 'USGS_MYB_MINERALS',
       'USGS Mineral Yearbook / physical mineral production',
       'manual://usgs/mineral-yearbook',
       'xlsx',
       'USGS MYB/MCS — séries physiques minières ; extraction semi-automatique ou manuelle'
FROM collect.data_providers
WHERE code = 'USGS'
ON CONFLICT (endpoint_code) DO NOTHING;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('MIN_PRD_GOL', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production or — donnée physique USGS'),
('MIN_PRD_COP', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production cuivre — donnée physique USGS'),
('MIN_PRD_IRN', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production minerai de fer — donnée physique USGS'),
('MIN_PRD_BAU', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production bauxite — donnée physique USGS'),
('MIN_PRD_STL', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production acier — donnée physique USGS'),
('MIN_PRD_ALU', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production aluminium — donnée physique USGS'),
('MIN_PRD_COB', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production cobalt — donnée physique USGS'),
('MIN_PRD_MAN', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production manganèse — donnée physique USGS'),
('MIN_PRD_CHR', 'PHYSICAL', 'STRICT', 1.00, FALSE, 0.70, 'Production chromite — donnée physique USGS')
ON CONFLICT (indicator_code) DO UPDATE SET
    nature_code = EXCLUDED.nature_code,
    confidence_policy = EXCLUDED.confidence_policy,
    physical_weight = EXCLUDED.physical_weight,
    imputation_allowed = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes = EXCLUDED.notes;

WITH src AS (
    SELECT * FROM (VALUES
        ('MIN_PRD_GOL', 'USGS_MYB_MINERALS', 'gold_mine_production',      'USGS MYB/MCS — Gold mine production', 75.00),
        ('MIN_PRD_COP', 'USGS_MYB_MINERALS', 'copper_mine_production',    'USGS MYB/MCS — Copper mine production', 75.00),
        ('MIN_PRD_IRN', 'USGS_MYB_MINERALS', 'iron_ore_production',       'USGS MYB/MCS — Iron ore production', 75.00),
        ('MIN_PRD_BAU', 'USGS_MYB_MINERALS', 'bauxite_production',        'USGS MYB/MCS — Bauxite production', 75.00),
        ('MIN_PRD_STL', 'USGS_MYB_MINERALS', 'steel_production',          'USGS MYB/MCS — Steel production', 75.00),
        ('MIN_PRD_ALU', 'USGS_MYB_MINERALS', 'aluminum_production',       'USGS MYB/MCS — Aluminum production', 75.00),
        ('MIN_PRD_COB', 'USGS_MYB_MINERALS', 'cobalt_mine_production',    'USGS MYB/MCS — Cobalt mine production', 75.00),
        ('MIN_PRD_MAN', 'USGS_MYB_MINERALS', 'manganese_mine_production', 'USGS MYB/MCS — Manganese production', 75.00),
        ('MIN_PRD_CHR', 'USGS_MYB_MINERALS', 'chromite_production',       'USGS MYB/MCS — Chromite production', 75.00)
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

INSERT INTO collect.source_registry (source_id, name, organization, api_type, base_url, status, priority, reliability_score)
VALUES
('USGS', 'USGS Mineral Statistics', 'USGS', 'XLSX/CSV',
 'https://www.usgs.gov/centers/national-minerals-information-center', 'PILOT', 2, 0.92)
ON CONFLICT (source_id) DO UPDATE SET
    status = EXCLUDED.status,
    reliability_score = EXCLUDED.reliability_score,
    updated_at = now();

INSERT INTO collect.source_registry_indicators
    (source_id, osa_code, source_code, endpoint, fallback, unit, frequency, decision, is_active)
VALUES
('USGS','MIN_PRD_GOL','gold_mine_production','USGS_MYB_MINERALS',NULL,'physical','annual','PILOT',TRUE),
('USGS','MIN_PRD_COP','copper_mine_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_IRN','iron_ore_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_BAU','bauxite_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_STL','steel_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_ALU','aluminum_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_COB','cobalt_mine_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_MAN','manganese_mine_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE),
('USGS','MIN_PRD_CHR','chromite_production','USGS_MYB_MINERALS',NULL,'tonnes','annual','PILOT',TRUE)
ON CONFLICT (source_id, source_code)
DO UPDATE SET
    osa_code = EXCLUDED.osa_code,
    endpoint = EXCLUDED.endpoint,
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
    WHERE indicator_code IN (
        'MIN_PRD_GOL','MIN_PRD_COP','MIN_PRD_IRN','MIN_PRD_BAU','MIN_PRD_STL',
        'MIN_PRD_ALU','MIN_PRD_COB','MIN_PRD_MAN','MIN_PRD_CHR'
    )
    AND is_active = TRUE;

    RAISE NOTICE 'P4A USGS physical mappings actifs : % / 9', v_count;
END $$;

COMMIT;
