\echo ''
\echo '=== BLOC A : VUE COMPLÈTE ==='

SELECT
    i.pillar_code,
    i.code,
    i.name_fr,

    dp.code AS provider,
    dp.base_url,

    pe.id AS endpoint_id,
    cs.source_indicator_code,
    cs.coverage_pct

FROM rf.indicators i

LEFT JOIN collect.indicator_source cs
    ON cs.indicator_code = i.code

LEFT JOIN collect.provider_endpoints pe
    ON pe.id = cs.endpoint_id

LEFT JOIN collect.data_providers dp
    ON dp.id = pe.provider_id

ORDER BY i.pillar_code, i.code;