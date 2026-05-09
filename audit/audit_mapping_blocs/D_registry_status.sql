\echo ''
\echo '=== BLOC D : REGISTRY ==='

SELECT
    i.code,
    i.name_fr,

    sri.source_id,
    sri.source_code,
    sri.decision

FROM rf.indicators i

LEFT JOIN collect.source_registry_indicators sri
    ON sri.osa_code = i.code

ORDER BY i.code;