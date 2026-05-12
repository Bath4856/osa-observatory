$ErrorActionPreference = "Stop"

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$Db = "osa_db"
$User = "postgres"
$HostName = "localhost"

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h $HostName -U $User -d $Db -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P8" }
}

Write-Host "========================================="
Write-Host " OSA — P8 DRY RUN TEST"
Write-Host "========================================="

Test-Sql @"
SELECT
    CASE WHEN to_regclass('rf.isa_certification_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_cert_policy,
    CASE WHEN to_regclass('rf.isa_publication_workflow_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_workflow_policy,
    CASE WHEN to_regclass('rf.isa_snapshot_freeze_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_freeze_policy,
    CASE WHEN to_regclass('rf.isa_open_data_dataset_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_open_data_policy,
    CASE WHEN to_regclass('rf.isa_premium_product_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_premium_policy,
    CASE WHEN to_regclass('rf.isa_api_endpoint_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_api_registry,
    CASE WHEN to_regclass('rf.isa_eparticipation_policy') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_eparticipation_policy;
"@

Test-Sql @"
SELECT
    CASE WHEN to_regclass('ma.v_isa_certification_engine') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_cert_engine,
    CASE WHEN to_regclass('ma.v_isa_publication_governance') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_pub_governance,
    CASE WHEN to_regclass('ma.v_isa_snapshot_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_snapshot,
    CASE WHEN to_regclass('ma.v_isa_open_data_catalog') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_open_data,
    CASE WHEN to_regclass('ma.v_isa_premium_catalog') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_premium,
    CASE WHEN to_regclass('ma.v_isa_api_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_api,
    CASE WHEN to_regclass('ma.v_isa_eparticipation_queue') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_eparticipation;
"@

Test-Sql @"
SELECT COUNT(*) AS certification_rows
FROM ma.v_isa_certification_engine;
"@

Test-Sql @"
SELECT certification_status, COUNT(*) AS nb
FROM ma.v_isa_certification_engine
GROUP BY certification_status
ORDER BY nb DESC;
"@

Test-Sql @"
SELECT COUNT(*) AS critical_nulls
FROM ma.v_isa_certification_engine
WHERE country_iso3 IS NULL
   OR year IS NULL
   OR certification_status IS NULL
   OR certification_confidence_proxy IS NULL
   OR certification_audit_hash IS NULL;
"@

Test-Sql @"
SELECT COUNT(*) AS out_of_bounds_confidence
FROM ma.v_isa_certification_engine
WHERE certification_confidence_proxy < 0
   OR certification_confidence_proxy > 1;
"@

Test-Sql @"
SELECT COUNT(*) AS publication_governance_rows
FROM ma.v_isa_publication_governance;
"@

Test-Sql @"
SELECT COUNT(*) AS snapshot_rows
FROM ma.v_isa_snapshot_registry;
"@

Test-Sql @"
SELECT COUNT(*) AS open_data_datasets
FROM ma.v_isa_open_data_catalog;
"@

Test-Sql @"
SELECT COUNT(*) AS premium_products
FROM ma.v_isa_premium_catalog;
"@

Test-Sql @"
SELECT COUNT(*) AS api_endpoints
FROM ma.v_isa_api_registry;
"@

Test-Sql @"
SELECT COUNT(*) AS eparticipation_rows
FROM ma.v_isa_eparticipation_queue;
"@

Test-Sql @"
SELECT access_class, monetization_class, COUNT(*) AS nb
FROM ma.v_isa_api_registry
GROUP BY access_class, monetization_class
ORDER BY nb DESC;
"@

Write-Host ""
Write-Host "✅ P8 dry-run terminé avec succès"
