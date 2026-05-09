\echo ''
\echo '=== RÉSUMÉ GLOBAL ==='

SELECT
    COUNT(*) AS total,
    COUNT(cs.id) AS mapped,
    COUNT(*) - COUNT(cs.id) AS unmapped,

    ROUND(100.0 * COUNT(cs.id) / COUNT(*), 2) AS pct

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code;