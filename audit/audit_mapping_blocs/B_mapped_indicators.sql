\echo ''
\echo '=== BLOC B : INDICATEURS MAPPÉS ==='

SELECT
    i.pillar_code,
    i.code,
    i.name_fr,

    dp.code AS provider,
    pe.id AS endpoint_id,
    cs.source_indicator_code

FROM rf.indicators i

JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

JOIN collect.provider_endpoints pe
    ON pe.id = cs.endpoint_id

JOIN collect.data_providers dp
    ON dp.id = pe.provider_id

WHERE cs.is_active = true

ORDER BY i.pillar_code, i.code;