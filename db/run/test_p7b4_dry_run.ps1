Write-Host "========================================="
Write-Host " OSA — P7B4 DRY RUN TEST"
Write-Host "========================================="

$ErrorActionPreference = "Stop"
$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"
$HOSTNAME = "127.0.0.1"

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -h $HOSTNAME -U $USER -d $DB -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7B4" -ForegroundColor Red
        exit 1
    }
}

Test-Sql "
WITH deps AS (
    SELECT
        to_regclass('rf.semantic_forecast_policy') AS policy_table,
        to_regclass('ma.v_semantic_forecastability_engine') AS engine_view,
        to_regclass('ma.v_isa_forecast_readiness') AS readiness_view
)
SELECT
    CASE WHEN policy_table IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_policy,
    CASE WHEN engine_view IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_engine,
    CASE WHEN readiness_view IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_readiness
FROM deps;
"

Test-Sql "SELECT COUNT(*) AS nb_forecast_policy_rows FROM rf.semantic_forecast_policy;"
Test-Sql "SELECT COUNT(*) AS nb_forecast_indicators FROM ma.v_semantic_forecastability_engine;"
Test-Sql "SELECT semantic_forecast_status, COUNT(*) AS nb FROM ma.v_semantic_forecastability_engine GROUP BY semantic_forecast_status ORDER BY nb DESC;"
Test-Sql "SELECT ml_forecast_decision, COUNT(*) AS nb FROM ma.v_semantic_forecastability_engine GROUP BY ml_forecast_decision ORDER BY nb DESC;"
Test-Sql "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(semantic_forecastability_score),3) AS avg_forecastability FROM ma.v_semantic_forecastability_engine GROUP BY pillar_code ORDER BY avg_forecastability;"
Test-Sql "SELECT COUNT(*) AS disabled_review FROM ma.v_semantic_forecastability_engine WHERE semantic_forecast_status = 'FORECAST_DISABLED_REVIEW';"
Test-Sql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_forecast_readiness;"

Write-Host ""
Write-Host "✅ P7B4 dry-run terminé avec succès" -ForegroundColor Green
