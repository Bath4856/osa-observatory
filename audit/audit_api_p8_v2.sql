-- =============================================================================
-- OSA / ISA — AUDIT API P8 V2 CONTRACTS
-- Corrigé : mg.api_contract_registry (pas pub.)
-- =============================================================================

\echo ''
\echo '========================================================'
\echo ' OSA / ISA — AUDIT API P8 V2'
\echo '========================================================'

\echo ''
\echo '=== 1. API contracts ==='
SELECT
    endpoint_code, http_method, access_class,
    auth_required, contract_status,
    LEFT(api_path, 50) AS api_path
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY access_class, endpoint_code;

\echo ''
\echo '=== 2. Usage API (derniers appels) ==='
SELECT
    endpoint_code, api_path, access_class,
    response_status, response_time_ms, rows_returned,
    TO_CHAR(request_timestamp, 'YYYY-MM-DD HH24:MI:SS') AS ts
FROM mg.api_usage_registry
ORDER BY request_timestamp DESC
LIMIT 20;

\echo ''
\echo '=== 3. Usage par endpoint ==='
SELECT
    endpoint_code, access_class,
    COUNT(*)                                AS nb_calls,
    ROUND(AVG(response_time_ms), 1)         AS avg_ms,
    ROUND(AVG(rows_returned), 0)            AS avg_rows,
    COUNT(*) FILTER (WHERE response_status != 200) AS nb_errors
FROM mg.api_usage_registry
GROUP BY endpoint_code, access_class
ORDER BY nb_calls DESC;

\echo ''
\echo '=== 4. Clés API actives ==='
SELECT
    api_key_id, owner_label, access_class,
    is_active,
    TO_CHAR(created_at,   'YYYY-MM-DD') AS created,
    TO_CHAR(expires_at,   'YYYY-MM-DD') AS expires,
    TO_CHAR(last_used_at, 'YYYY-MM-DD HH24:MI') AS last_used
FROM mg.api_key_registry
ORDER BY created_at DESC;

\echo ''
\echo '=== 5. Release manifest ==='
SELECT release_code, release_status, semantic_version,
       nb_datasets, nb_endpoints, nb_public_endpoints, nb_expert_endpoints
FROM pub.v_isa_release_manifest;

\echo ''
\echo '✅ AUDIT API P8 V2 COMPLETE'
