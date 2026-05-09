\echo ''
\echo '=== BLOC F : TAUX PAR PILIER ==='

SELECT
    i.pillar_code,

    COUNT(*) AS total,
    COUNT(cs.id) AS mapped,

    ROUND(100.0 * COUNT(cs.id) / COUNT(*), 2) AS pct

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

GROUP BY i.pillar_code
ORDER BY i.pillar_code;