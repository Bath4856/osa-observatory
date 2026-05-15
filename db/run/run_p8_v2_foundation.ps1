param(
  [string]$DbHost = "127.0.0.1",
  [string]$DbPort = "5432",
  [string]$DbName = "osa_db",
  [string]$DbUser = "postgres"
)

$ErrorActionPreference = "Stop"
$Psql = "psql"

Write-Host "========================================="
Write-Host " OSA — RUN P8 V2 FOUNDATION"
Write-Host "========================================="

Write-Host ">>> Audit inventaire P8 OPS"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p8_ops_inventory.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur audit inventaire P8 OPS" }

Write-Host ">>> Audit colonnes sources P8 V2"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/list_p8_v2_source_columns.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur audit colonnes sources P8 V2" }

Write-Host ">>> Pré-test dépendances P8 V2 Foundation"
$precheck = @"
WITH required_sources AS (
    SELECT unnest(ARRAY[
        'v_isa_observed_scores_by_country_year',
        'v_isa_observed_scores_by_pillar',
        'v_isa_strategic_diagnostic_engine',
        'v_isa_candidate_intervention_catalog'
    ]) AS table_name
),
existing_sources AS (
    SELECT table_name FROM information_schema.views WHERE table_schema = 'ma'
)
SELECT
    COUNT(*) AS required_sources,
    COUNT(e.table_name) AS found_sources,
    CASE WHEN COUNT(*) = COUNT(e.table_name) THEN 'OK' ELSE 'MISSING_SOURCE_VIEW' END AS check_required_sources
FROM required_sources r
LEFT JOIN existing_sources e ON e.table_name = r.table_name;
"@
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $precheck
if ($LASTEXITCODE -ne 0) { throw "Erreur pré-test P8 V2 Foundation" }

Write-Host ">>> SQL : db/patch_db/patch_p8_v2_foundation.sql"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "db/patch_db/patch_p8_v2_foundation.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur SQL P8 V2 Foundation" }

Write-Host ">>> Rapport P8 V2 Foundation"
& $Psql -h $DbHost -p $DbPort -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit/p8_v2_foundation_report.sql"
if ($LASTEXITCODE -ne 0) { throw "Erreur rapport P8 V2 Foundation" }

Write-Host "✅ P8 V2 Foundation installé"
