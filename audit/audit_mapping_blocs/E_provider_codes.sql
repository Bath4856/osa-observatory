\echo ''
\echo '=== BLOC E : PROVIDERS ==='

SELECT
    dp.code AS provider,
    sri.source_code,
    sri.osa_code,
    sri.decision

FROM collect.source_registry_indicators sri

JOIN collect.source_registry sr
    ON sr.source_id = sri.source_id

LEFT JOIN collect.data_providers dp
    ON dp.code = sr.source_id

ORDER BY dp.code;