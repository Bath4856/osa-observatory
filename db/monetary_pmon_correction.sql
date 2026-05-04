DELETE FROM ma.computed_values WHERE indicator_code = 'MON_PMON_CORR';

INSERT INTO ma.computed_indicators
    (code, pillar_code, indicator_type, name_fr, name_en, formula)
VALUES ('MON_PMON_CORR', 'PMON', 'CORRECTION',
    'Score PMON corrige souverainete monetaire',
    'PMON score corrected for monetary sovereignty',
    'PMON_L2 x MON_SOV_FACTOR')
ON CONFLICT (code) DO NOTHING;

INSERT INTO ma.computed_values
    (indicator_code, country_iso3, year, value, confidence, components)
SELECT
    'MON_PMON_CORR',
    ps.country_iso3,
    ps.year,
    ROUND((ps.score * cmr.mon_sov_factor)::numeric, 6),
    ROUND((ps.coverage_pct / 100.0 * cmr.mon_sov_factor)::numeric, 3),
    jsonb_build_object(
        'pmon_brut', ROUND(ps.score::numeric, 6),
        'mon_sov_factor', cmr.mon_sov_factor,
        'regime_type', cmr.regime_type,
        'nb_indicators', ps.indicators_used,
        'coverage_pct', ps.coverage_pct,
        'version', '1.0'
    )
FROM ma.pillar_scores ps
JOIN ma.country_monetary_regime cmr
    ON  cmr.country_iso3 = ps.country_iso3
    AND ps.year >= cmr.valid_from
    AND (cmr.valid_to IS NULL OR ps.year <= cmr.valid_to)
WHERE ps.pillar_code = 'PMON';

SELECT
    cmr.regime_type,
    COUNT(DISTINCT cv.country_iso3) AS nb_pays,
    ROUND(AVG((cv.components->>'pmon_brut')::numeric)::numeric,4) AS pmon_brut_moy,
    ROUND(AVG(cv.value)::numeric,4) AS pmon_corr_moy,
    ROUND(AVG(cmr.mon_sov_factor)::numeric,2) AS sov_factor
FROM ma.computed_values cv
JOIN ma.country_monetary_regime cmr
    ON  cmr.country_iso3 = cv.country_iso3
    AND cmr.is_current = true
WHERE cv.indicator_code = 'MON_PMON_CORR'
GROUP BY cmr.regime_type
ORDER BY cmr.regime_type;