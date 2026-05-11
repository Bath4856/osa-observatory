$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — RUN P7C DYNAMIC AGGREGATION ENGINE"
Write-Host "========================================="

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

Write-Host ">>> Pré-test dépendances P7C"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c "
WITH deps AS (
    SELECT
        to_regclass('ma.v_semantic_strategic_weighting_engine') IS NOT NULL AS has_weighting_engine,
        to_regclass('ma.v_isa_dynamic_weighting_readiness') IS NOT NULL AS has_weighting_readiness
), cols AS (
    SELECT COUNT(*) AS found_cols
    FROM information_schema.columns
    WHERE table_schema = 'ma'
      AND table_name = 'v_semantic_strategic_weighting_engine'
      AND column_name IN (
        'indicator_code','pillar_code','indicator_name','semantic_code',
        'semantic_confidence_dynamic','semantic_operational_score',
        'semantic_forecastability_score','semantic_sovereignty_score',
        'semantic_sovereignty_vulnerability','isa_dynamic_weight','ml_dynamic_weight',
        'forecast_dynamic_weight','sovereignty_dynamic_weight','systemic_vulnerability_weight',
        'strategic_weighting_class','isa_weighting_decision','ml_weighting_decision',
        'forecast_weighting_decision','semantic_sovereignty_class'
      )
)
SELECT
    CASE WHEN has_weighting_engine THEN 'OK' ELSE 'MISSING' END AS check_weighting_engine,
    CASE WHEN has_weighting_readiness THEN 'OK' ELSE 'MISSING' END AS check_weighting_readiness,
    CASE WHEN found_cols = 19 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps, cols;
"

$files = @(
  "db\patch_db\patch_p7c_dynamic_aggregation.sql",
  "db\views\ma\v_semantic_dynamic_aggregation_engine.sql",
  "db\views\ma\v_isa_dynamic_aggregation_readiness.sql"
)

foreach ($file in $files) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ">>> Rapport P7C"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "audit\p7c_dynamic_aggregation_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P7C" -ForegroundColor Red
    exit 1
}

Write-Host "✅ P7C Dynamic Aggregation Engine installé" -ForegroundColor Green
