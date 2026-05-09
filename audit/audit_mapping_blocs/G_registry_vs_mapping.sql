\echo ''
\echo '=== BLOC G : REGISTRY vs MAPPING ==='

SELECT
    i.code,
    i.name_fr,

    CASE
        WHEN cs.id IS NOT NULL THEN 'MAPPÉ'
        ELSE 'NON MAPPÉ'
    END AS mapping_status,

    sri.decision

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

LEFT JOIN collect.source_registry_indicators sri
    ON sri.osa_code = i.code

ORDER BY i.code;