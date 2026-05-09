\echo ''
\echo '=== BLOC C : NON MAPPÉS ==='

SELECT
    i.pillar_code,
    i.code,
    i.name_fr

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

WHERE cs.id IS NULL

ORDER BY i.pillar_code, i.code;