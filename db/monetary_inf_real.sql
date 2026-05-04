-- ================================================================
-- M5 : Calcul MON_INF_REAL
-- Inflation ajustée par contrainte monétaire (MON_SOV_FACTOR)
-- Formule : MON_INF × (1 + (1 - MON_SOV_FACTOR) × 0.5)
-- OSA Observatory — Mai 2026
-- ================================================================

-- Suppression préalable
DELETE FROM ma.computed_values
WHERE indicator_code = 'MON_INF_REAL';

-- Calcul et insertion
INSERT INTO ma.computed_values
    (indicator_code, country_iso3, year, value, confidence, components)
SELECT
    'MON_INF_REAL',
    iv.country_iso3,
    iv.year,
    ROUND(GREATEST(0, LEAST(1,
        ABS(iv.processed_value) / 100.0 *
        (1 + (1 - cmr.mon_sov_factor) * 0.5)
    ))::numeric, 6),
    ROUND((iv.confidence_score * cmr.mon_sov_factor)::numeric, 3),
    jsonb_build_object(
        'mon_inf_officiel',  ROUND(iv.processed_value::numeric, 4),
        'mon_sov_factor',    cmr.mon_sov_factor,
        'regime_type',       cmr.regime_type,
        'correction_pct',    ROUND(((1 - cmr.mon_sov_factor) * 50)::numeric, 1),
        'formule',           'MON_INF x (1 + (1 - SOV) x 0.5)',
        'version',           '1.0'
    )
FROM ma.indicator_values iv
JOIN ma.country_monetary_regime cmr
    ON  cmr.country_iso3 = iv.country_iso3
    AND iv.year >= cmr.valid_from
    AND (cmr.valid_to IS NULL OR iv.year <= cmr.valid_to)
WHERE iv.indicator_code = 'MON_INF'
  AND iv.processed_value IS NOT NULL
  AND iv.year BETWEEN 2020 AND 2024;

-- Verification par regime
SELECT
    cmr.regime_type,
    COUNT(DISTINCT cv.country_iso3) AS nb_pays,
    COUNT(*) AS nb_obs,
    ROUND(AVG(
        (cv.components->>'mon_inf_officiel')::numeric
    )::numeric, 2) AS inf_officielle_moy,
    ROUND(AVG(cv.value)::numeric, 2) AS inf_reelle_moy,
    ROUND(AVG(
        (cv.components->>'correction_pct')::numeric
    )::numeric, 1) AS correction_pct_moy
FROM ma.computed_values cv
JOIN ma.country_monetary_regime cmr
    ON  cmr.country_iso3 = cv.country_iso3
    AND cmr.is_current = true
WHERE cv.indicator_code = 'MON_INF_REAL'
GROUP BY cmr.regime_type
ORDER BY cmr.regime_type;