SELECT
    indicator_code,
    COUNT(*) AS nb_lignes,
    COUNT(DISTINCT country_iso3) AS nb_pays,
    COUNT(DISTINCT year) AS nb_annees,
    ROUND(MIN(value)::numeric, 4) AS thr_min,
    ROUND(MAX(value)::numeric, 4) AS thr_max,
    ROUND(AVG(value)::numeric, 4) AS thr_moy
FROM ma.computed_values
WHERE indicator_code LIKE 'THR_%'
GROUP BY indicator_code
ORDER BY indicator_code;
