Write-Host "========================================="
Write-Host " OSA — RUN P7B4 SEMANTIC FORECASTABILITY"
Write-Host "========================================="

$ErrorActionPreference = "Stop"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"
$HOSTNAME = "127.0.0.1"

function Run-SqlFile($file) {
    Write-Host ">>> SQL : $file"
    & $PSQL -h $HOSTNAME -U $USER -d $DB -v ON_ERROR_STOP=1 -f $file
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Erreur SQL : $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ">>> Pré-test dépendances P7B4"
& $PSQL -h $HOSTNAME -U $USER -d $DB -v ON_ERROR_STOP=1 -c "
WITH deps AS (
    SELECT
        to_regclass('ma.v_isa_semantic_operations') AS ops_view,
        to_regclass('ma.v_semantic_confidence_engine') AS confidence_view,
        to_regclass('ma.v_semantic_operational_policy_engine') AS operational_view
), cols AS (
    SELECT
        COUNT(*) FILTER (WHERE column_name='indicator_code') AS has_indicator_code,
        COUNT(*) FILTER (WHERE column_name='pillar_code') AS has_pillar_code,
        COUNT(*) FILTER (WHERE column_name='semantic_code') AS has_semantic_code,
        COUNT(*) FILTER (WHERE column_name='semantic_confidence_dynamic') AS has_dynamic_confidence,
        COUNT(*) FILTER (WHERE column_name='semantic_operational_score') AS has_operational_score,
        COUNT(*) FILTER (WHERE column_name='semantic_operational_status') AS has_operational_status,
        COUNT(*) FILTER (WHERE column_name='isa_operational_decision') AS has_isa_decision,
        COUNT(*) FILTER (WHERE column_name='l2_imputation_decision') AS has_l2_decision,
        COUNT(*) FILTER (WHERE column_name='ml_operational_decision') AS has_ml_decision
    FROM information_schema.columns
    WHERE table_schema='ma'
      AND table_name='v_isa_semantic_operations'
)
SELECT
    CASE WHEN ops_view IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_ops_view,
    CASE WHEN confidence_view IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_confidence_view,
    CASE WHEN operational_view IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_operational_view,
    CASE WHEN has_indicator_code=1 AND has_pillar_code=1 AND has_semantic_code=1
           AND has_dynamic_confidence=1 AND has_operational_score=1
           AND has_operational_status=1 AND has_isa_decision=1
           AND has_l2_decision=1 AND has_ml_decision=1
         THEN 'OK' ELSE 'MISSING_COLUMNS' END AS check_required_columns
FROM deps, cols;
"
if ($LASTEXITCODE -ne 0) { exit 1 }

Run-SqlFile "db\patch_db\patch_p7b4_semantic_forecastability.sql"
Run-SqlFile "db\views\ma\v_semantic_forecastability_engine.sql"
Run-SqlFile "db\views\ma\v_isa_forecast_readiness.sql"

Write-Host ">>> Rapport P7B4"
& $PSQL -h $HOSTNAME -U $USER -d $DB -v ON_ERROR_STOP=1 -f "audit\p7b4_semantic_forecastability_report.sql"
if ($LASTEXITCODE -ne 0) {
    Write-Host "Erreur rapport P7B4" -ForegroundColor Red
    exit 1
}

Write-Host "✅ P7B4 Semantic Forecastability installé" -ForegroundColor Green
