-- OSA Observatory — Indicateurs TRAJECTOIRE Sprint 22
-- PNUM_DIGITAL_CAPTURE + PMON_RESERVE_CAPTURE + ECO_FORMAL_TRAJECTORY
-- Date : 11 juin 2026

-- 1. Enregistrement rf.indicators
INSERT INTO rf.indicators (code, pillar_code, indicator_group, name_fr, name_en, unit_code, direction, description, imputation_regime, is_active)
VALUES
('PNUM_DIGITAL_CAPTURE','PNUM','TRAJECTOIRE',
 'Capture souveraine numerique — taux de croissance adoption internet',
 'Digital sovereign capture — internet adoption growth rate',
 'PCT','+',
 'Taux de croissance annuel de l adoption internet. L1 ONLY. Source : ITU/WB PNUM_INTERNET_USERS.',
 'COMPUTED', true),
('PMON_RESERVE_CAPTURE','PMON','TRAJECTOIRE',
 'Capture souveraine monetaire — taux de variation des reserves de change',
 'Monetary sovereign capture — foreign exchange reserves growth rate',
 'PCT','+',
 'Taux de variation annuel des reserves de change. L1 ONLY. Source : WB MON_RES.',
 'COMPUTED', true)
ON CONFLICT (code) DO NOTHING;

-- 2. PNUM_DIGITAL_CAPTURE L1 — depuis PNUM_INTERNET_USERS L1
INSERT INTO ma.indicator_values (indicator_code, country_iso3, year, layer_id, raw_value, quality_flag, is_estimated, source_id)
WITH base AS (
    SELECT DISTINCT ON (country_iso3, year) country_iso3, year, raw_value
    FROM ma.indicator_values WHERE indicator_code = 'PNUM_INTERNET_USERS' AND layer_id = 1
    ORDER BY country_iso3, year, raw_value
),
traj AS (
    SELECT country_iso3, year,
           ROUND((raw_value - LAG(raw_value) OVER (PARTITION BY country_iso3 ORDER BY year))
                 / NULLIF(LAG(raw_value) OVER (PARTITION BY country_iso3 ORDER BY year),0)*100,4) AS delta
    FROM base
)
SELECT 'PNUM_DIGITAL_CAPTURE', country_iso3, year, 1, delta, 'OK', false,
       (SELECT MIN(source_id) FROM ma.indicator_values WHERE indicator_code='PNUM_INTERNET_USERS' AND layer_id=1)
FROM traj WHERE delta IS NOT NULL
ON CONFLICT DO NOTHING;

-- 3. PMON_RESERVE_CAPTURE L1 — depuis MON_RES L1
INSERT INTO ma.indicator_values (indicator_code, country_iso3, year, layer_id, raw_value, quality_flag, is_estimated, source_id)
WITH base AS (
    SELECT DISTINCT ON (country_iso3, year) country_iso3, year, raw_value
    FROM ma.indicator_values WHERE indicator_code = 'MON_RES' AND layer_id = 1
    ORDER BY country_iso3, year, raw_value
),
traj AS (
    SELECT country_iso3, year,
           ROUND((raw_value - LAG(raw_value) OVER (PARTITION BY country_iso3 ORDER BY year))
                 / NULLIF(LAG(raw_value) OVER (PARTITION BY country_iso3 ORDER BY year),0)*100,4) AS delta
    FROM base
)
SELECT 'PMON_RESERVE_CAPTURE', country_iso3, year, 1, delta, 'OK', false,
       (SELECT MIN(source_id) FROM ma.indicator_values WHERE indicator_code='MON_RES' AND layer_id=1)
FROM traj WHERE delta IS NOT NULL
ON CONFLICT DO NOTHING;

-- 4. ECO_FORMAL_TRAJECTORY L1 — depuis ECO_INFORMAL_RATE L1
INSERT INTO ma.indicator_values (indicator_code, country_iso3, year, layer_id, raw_value, quality_flag, is_estimated, source_id)
WITH base AS (
    SELECT country_iso3, iv.year, 100 - raw_value AS taux_formalisation
    FROM ma.indicator_values iv WHERE indicator_code = 'ECO_INFORMAL_RATE' AND layer_id = 1
),
traj AS (
    SELECT country_iso3, year,
           taux_formalisation - LAG(taux_formalisation) OVER (PARTITION BY country_iso3 ORDER BY year) AS delta
    FROM base
),
eligible AS (
    SELECT country_iso3 FROM base GROUP BY country_iso3 HAVING COUNT(DISTINCT year) >= 2
)
SELECT 'ECO_FORMAL_TRAJECTORY', t.country_iso3, t.year, 1, ROUND(t.delta,4), 'OK', false, 20
FROM traj t JOIN eligible e ON e.country_iso3 = t.country_iso3
WHERE t.delta IS NOT NULL
ON CONFLICT DO NOTHING;
