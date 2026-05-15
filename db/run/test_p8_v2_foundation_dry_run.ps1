param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)

$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — P8 V2 FOUNDATION DRY RUN"
Write-Host "========================================="

function Run-TestSql {
  param([string]$Sql)
  Write-Host ""
  Write-Host ">>> Test SQL"
  & $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Sql
  if ($LASTEXITCODE -ne 0) { throw "Erreur dry-run P8 V2 Foundation" }
}

Run-TestSql @"
SELECT
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='pub') THEN 'OK' ELSE 'KO' END AS check_pub_schema,
    CASE WHEN EXISTS (SELECT 1 FROM information_schema.schemata WHERE schema_name='archive') THEN 'OK' ELSE 'KO' END AS check_archive_schema,
    CASE WHEN to_regclass('mg.release_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_release_registry,
    CASE WHEN to_regclass('mg.asset_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_asset_registry,
    CASE WHEN to_regclass('mg.publication_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_publication_registry,
    CASE WHEN to_regclass('mg.api_contract_registry') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_api_contract_registry,
    CASE WHEN to_regclass('mg.publication_audit_log') IS NOT NULL THEN 'OK' ELSE 'KO' END AS check_audit_log;
"@

Run-TestSql "SELECT package_code, package_status, replacement_package FROM rf.package_lifecycle WHERE package_code IN ('P8OPS','P8V2') ORDER BY package_code;"
Run-TestSql "SELECT COUNT(*) AS release_rows FROM mg.release_registry WHERE release_code='P8V2_2026_CANDIDATE';"
Run-TestSql "SELECT COUNT(*) AS asset_rows FROM mg.asset_registry WHERE release_code='P8V2_2026_CANDIDATE';"
Run-TestSql "SELECT COUNT(*) AS publication_rows FROM mg.publication_registry WHERE release_code='P8V2_2026_CANDIDATE';"
Run-TestSql "SELECT COUNT(*) AS api_contract_rows FROM mg.api_contract_registry WHERE release_code='P8V2_2026_CANDIDATE';"

Run-TestSql @"
SELECT COUNT(*) AS unclassified_publications
FROM mg.publication_registry
WHERE release_code='P8V2_2026_CANDIDATE'
  AND (access_class IS NULL OR publication_status IS NULL OR public_api_path IS NULL);
"@

Run-TestSql @"
SELECT COUNT(*) AS invalid_api_contracts
FROM mg.api_contract_registry
WHERE release_code='P8V2_2026_CANDIDATE'
  AND (
      api_version <> 'v2'
      OR http_method <> 'GET'
      OR api_path NOT LIKE '/api/v2/%'
      OR contract_status IS NULL
      OR access_class IS NULL
  );
"@

Run-TestSql @"
SELECT COUNT(*) AS core_source_views_found
FROM information_schema.views
WHERE table_schema='ma'
  AND table_name IN (
    'v_isa_observed_scores_by_country_year',
    'v_isa_observed_scores_by_pillar',
    'v_isa_strategic_diagnostic_engine',
    'v_isa_candidate_intervention_catalog'
  );
"@

Write-Host ""
Write-Host "✅ P8 V2 foundation dry-run terminé avec succès"
