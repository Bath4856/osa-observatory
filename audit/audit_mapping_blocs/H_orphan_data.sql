\echo ''
\echo '=== BLOC H : DONNÉES ORPHELINES ==='

SELECT
    i.pillar_code,
    v.indicator_code,
    i.name_fr,

    COUNT(*) AS obs,
    COUNT(DISTINCT v.country_iso3) AS countries,

    ROUND(AVG(v.confidence_score), 3) AS confidence,

    MIN(v.year) AS start_year,
    MAX(v.year) AS end_year

FROM ma.indicator_values v

JOIN rf.indicators i
    ON i.code = v.indicator_code

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = v.indicator_code

WHERE cs.id IS NULL

GROUP BY i.pillar_code, v.indicator_code, i.name_fr

ORDER BY obs DESC;