\echo ''
\echo '========================================================'
\echo ' OSA / ISA — P8 OPERATIONALIZATION REPORT'
\echo '========================================================'

\echo ''
\echo '=== 0. Colonnes sources P8 ==='
\i audit/list_p8_source_columns.sql

\echo ''
\echo '=== 1. Certification status ==='
SELECT certification_status, COUNT(*) AS nb
FROM ma.v_isa_certification_engine
GROUP BY certification_status
ORDER BY nb DESC;

\echo ''
\echo '=== 2. Publication governance ==='
SELECT workflow_status, publication_governance_status, COUNT(*) AS nb
FROM ma.v_isa_publication_governance
GROUP BY workflow_status, publication_governance_status
ORDER BY nb DESC;

\echo ''
\echo '=== 3. Snapshot registry ==='
SELECT snapshot_type, snapshot_freeze_status, COUNT(*) AS nb
FROM ma.v_isa_snapshot_registry
GROUP BY snapshot_type, snapshot_freeze_status
ORDER BY nb DESC;

\echo ''
\echo '=== 4. Open data catalog ==='
SELECT dataset_code, access_class, api_path, dataset_rows, open_data_delivery_status
FROM ma.v_isa_open_data_catalog
ORDER BY dataset_code;

\echo ''
\echo '=== 5. Premium catalog ==='
SELECT product_code, monetization_class, api_path, product_source_rows, premium_delivery_status
FROM ma.v_isa_premium_catalog
ORDER BY product_code;

\echo ''
\echo '=== 6. API registry ==='
SELECT endpoint_code, access_class, monetization_class, auth_required, api_governance_status
FROM ma.v_isa_api_registry
ORDER BY endpoint_code;

\echo ''
\echo '=== 7. E-participation queue ==='
SELECT eparticipation_queue_status, COUNT(*) AS nb
FROM ma.v_isa_eparticipation_queue
GROUP BY eparticipation_queue_status
ORDER BY nb DESC;

\echo ''
\echo '=== RAPPORT P8 TERMINÉ ==='
