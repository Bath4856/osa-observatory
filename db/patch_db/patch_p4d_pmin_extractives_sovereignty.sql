BEGIN;

INSERT INTO rf.indicator_nature
    (indicator_code, nature_code, confidence_policy, physical_weight, imputation_allowed, exclusion_threshold, notes)
VALUES
('MIN_COM',     'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Commerce minier'),
('MIN_DEP',     'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Dépendance aux exportations minières'),
('MIN_EXP_FUL', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Exportations minéraux FUL'),
('MIN_EXP_PRC', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Exportations minéraux PRC'),
('MIN_EXP_ORE', 'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Exportations minéraux ORE'),
('MIN_SEC',     'EVENT',      'MODERATE', 0.50, TRUE, 0.45, 'Sécurité sites miniers'),
('MIN_TRAC',    'STRUCTURAL', 'MODERATE', 0.55, TRUE, 0.45, 'Traçabilité minière'),
('MIN_INV',     'STRUCTURAL', 'MODERATE', 0.50, TRUE, 0.40, 'Investissement minier'),
('MIN_EMP',     'STRUCTURAL', 'MODERATE', 0.45, TRUE, 0.40, 'Emploi minier'),
('MIN_LOC',     'STRUCTURAL', 'MODERATE', 0.45, TRUE, 0.40, 'Contenu local minier')
ON CONFLICT (indicator_code) DO UPDATE SET
    nature_code = EXCLUDED.nature_code,
    confidence_policy = EXCLUDED.confidence_policy,
    physical_weight = EXCLUDED.physical_weight,
    imputation_allowed = EXCLUDED.imputation_allowed,
    exclusion_threshold = EXCLUDED.exclusion_threshold,
    notes = EXCLUDED.notes;

WITH src AS (
    SELECT * FROM (VALUES
        ('MIN_COM',     'COMTRADE_MINERALS',  'mineral_trade_total',       'UN Comtrade/OSA — commerce minier', 65.00),
        ('MIN_DEP',     'COMTRADE_MINERALS',  'mineral_export_dependence', 'UN Comtrade/OSA — dépendance exports', 65.00),
        ('MIN_EXP_FUL', 'COMTRADE_MINERALS',  'mineral_exports_ful',       'UN Comtrade/OSA — exports FUL', 65.00),
        ('MIN_EXP_PRC', 'COMTRADE_MINERALS',  'mineral_exports_prc',       'UN Comtrade/OSA — exports PRC', 65.00),
        ('MIN_EXP_ORE', 'COMTRADE_MINERALS',  'mineral_exports_ore',       'UN Comtrade/OSA — exports ORE', 65.00),
        ('MIN_SEC',     'OSA_PMIN_GEOSPATIAL','mining_site_security',      'OSA/ACLED — sécurité sites miniers', 60.00),
        ('MIN_TRAC',    'EITI_COUNTRY_STATUS','mining_traceability',       'EITI/OSA — traçabilité minière', 60.00),
        ('MIN_INV',     'EITI_COUNTRY_STATUS','mining_investment',         'EITI/OSA — investissement minier', 55.00),
        ('MIN_EMP',     'EITI_COUNTRY_STATUS','mining_employment',         'EITI/OSA — emploi minier', 55.00),
        ('MIN_LOC',     'EITI_COUNTRY_STATUS','local_content_mining',      'EITI/OSA — contenu local', 55.00)
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
    WHERE indicator_code IN (
        'MIN_COM','MIN_DEP','MIN_EXP_FUL','MIN_EXP_PRC','MIN_EXP_ORE',
        'MIN_SEC','MIN_TRAC','MIN_INV','MIN_EMP','MIN_LOC'
    )
    AND is_active = TRUE;
    RAISE NOTICE 'P4D extractive sovereignty mappings actifs : % / 10', v_count;
END $$;

COMMIT;
