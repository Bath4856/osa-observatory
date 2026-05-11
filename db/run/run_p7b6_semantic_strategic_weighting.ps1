$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — RUN P7B6 SEMANTIC STRATEGIC WEIGHTING"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
if (-not (Test-Path $Psql)) { $Psql = "psql" }

$DbHost = "127.0.0.1"
$DbUser = "postgres"
$DbName = "osa_db"

function Invoke-OsaSqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $Psql -h $DbHost -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ">>> Pré-test dépendances P7B6"
$Pretest = @"
WITH required_columns AS (
    SELECT unnest(ARRAY[
        'indicator_code',
        'pillar_code',
        'indicator_name',
        'semantic_code',
        'semantic_confidence_dynamic',
        'semantic_operational_score',
        'semantic_forecastability_score',
        'semantic_sovereignty_score',
        'semantic_sovereignty_vulnerability',
        'semantic_sovereignty_class',
        'isa_sovereignty_decision',
        'sovereignty_reason',
        'semantic_operational_status',
        'isa_operational_decision',
        'l2_imputation_decision',
        'ml_operational_decision',
        'semantic_forecast_status',
        'ml_forecast_decision',
        'allowed_forecast_horizon_years',
        'matrix_sovereignty_weight',
        'physicality_score',
        'dependency_score',
        'resilience_score',
        'strategic_priority',
        'ml_priority',
        'volatility_class',
        'risk_profile',
        'sovereignty_role'
    ]) AS column_name
), missing AS (
    SELECT r.column_name
    FROM required_columns r
    WHERE NOT EXISTS (
        SELECT 1
        FROM information_schema.columns c
        WHERE c.table_schema = 'ma'
          AND c.table_name = 'v_semantic_sovereignty_engine'
          AND c.column_name = r.column_name
    )
)
SELECT
    CASE WHEN to_regclass('ma.v_semantic_sovereignty_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_sovereignty_engine,
    CASE WHEN to_regclass('ma.v_isa_sovereignty_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_sovereignty_readiness,
    CASE WHEN COUNT(*) = 0 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM missing;
"@

& $Psql -h $DbHost -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $Pretest
if ($LASTEXITCODE -ne 0) { exit 1 }

Invoke-OsaSqlFile "db\patch_db\patch_p7b6_semantic_strategic_weighting.sql"
Invoke-OsaSqlFile "db\views\ma\v_semantic_strategic_weighting_engine.sql"
Invoke-OsaSqlFile "db\views\ma\v_isa_dynamic_weighting_readiness.sql"

Write-Host ">>> Rapport P7B6"
& $Psql -h $DbHost -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -f "audit\p7b6_semantic_strategic_weighting_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P7B6" -ForegroundColor Red
    exit 1
}

Write-Host "✅ P7B6 Semantic Strategic Weighting installé" -ForegroundColor Green
