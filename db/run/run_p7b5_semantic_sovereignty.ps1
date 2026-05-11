Write-Host "========================================="
Write-Host " OSA — RUN P7B5 SEMANTIC SOVEREIGNTY"
Write-Host "========================================="

$ErrorActionPreference = "Stop"

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

Write-Host ">>> Pré-test dépendances P7B5"

& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c @"
SELECT
  CASE WHEN to_regclass('ma.v_semantic_forecastability_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_forecast_engine,
  CASE WHEN to_regclass('ma.v_isa_forecast_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_forecast_readiness,
  CASE WHEN to_regclass('rf.semantic_forecast_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_forecast_policy,
  CASE
    WHEN (
      SELECT COUNT(*)
      FROM information_schema.columns
      WHERE table_schema='ma'
        AND table_name='v_semantic_forecastability_engine'
        AND column_name IN (
          'indicator_code',
          'pillar_code',
          'indicator_name',
          'semantic_code',
          'semantic_confidence_dynamic',
          'semantic_operational_score',
          'semantic_forecastability_score',
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
          'risk_profile'
        )
    ) = 22 THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns;
"@

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur pré-test P7B5"
    exit 1
}

$files = @(
  "db\patch_db\patch_p7b5_semantic_sovereignty.sql",
  "db\views\ma\v_semantic_sovereignty_engine.sql",
  "db\views\ma\v_isa_sovereignty_readiness.sql"
)

foreach ($file in $files) {
    Write-Host ">>> SQL : $file"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur SQL : $file"
        exit 1
    }
}

Write-Host ">>> Rapport P7B5"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "audit\p7b5_semantic_sovereignty_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur rapport P7B5"
    exit 1
}

Write-Host "✅ P7B5 Semantic Sovereignty Engine installé"
