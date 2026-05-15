\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P8 V2 FOUNDATION REPORT'
\echo '========================================================'
\echo ''

\echo '=== 1. Schemas ==='
SELECT schema_name
FROM information_schema.schemata
WHERE schema_name IN ('pub','archive','mg','rf','ma')
ORDER BY schema_name;

\echo ''
\echo '=== 2. Package lifecycle ==='
SELECT package_code, package_label, package_status, replacement_package, notes
FROM rf.package_lifecycle
WHERE package_code IN ('P8OPS','P8V2')
ORDER BY package_code;

\echo ''
\echo '=== 3. Release registry ==='
SELECT release_code, release_label, release_family, release_status, semantic_version, data_period_start, data_period_end
FROM mg.release_registry
WHERE release_family IN ('P8V2','P8OPS')
ORDER BY release_code;

\echo ''
\echo '=== 4. Asset registry distribution ==='
SELECT classification, migration_status, COUNT(*) AS nb
FROM mg.asset_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
GROUP BY classification, migration_status
ORDER BY classification, migration_status;

\echo ''
\echo '=== 5. Publication registry ==='
SELECT dataset_code, access_class, publication_status, source_view, target_view, public_api_path
FROM mg.publication_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY dataset_code;

\echo ''
\echo '=== 6. API contract registry ==='
SELECT endpoint_code, api_version, http_method, api_path, access_class, auth_required, contract_status
FROM mg.api_contract_registry
WHERE release_code = 'P8V2_2026_CANDIDATE'
ORDER BY endpoint_code;

\echo ''
\echo '=== 7. Foundation integrity checks ==='
SELECT
    (SELECT COUNT(*) FROM mg.release_registry WHERE release_code = 'P8V2_2026_CANDIDATE') AS release_rows,
    (SELECT COUNT(*) FROM mg.asset_registry WHERE release_code = 'P8V2_2026_CANDIDATE') AS asset_rows,
    (SELECT COUNT(*) FROM mg.publication_registry WHERE release_code = 'P8V2_2026_CANDIDATE') AS publication_rows,
    (SELECT COUNT(*) FROM mg.api_contract_registry WHERE release_code = 'P8V2_2026_CANDIDATE') AS api_contract_rows,
    (SELECT COUNT(*) FROM mg.publication_audit_log WHERE release_code = 'P8V2_2026_CANDIDATE') AS audit_log_rows;

\echo ''
\echo '=== RAPPORT P8 V2 FOUNDATION TERMINÉ ==='
