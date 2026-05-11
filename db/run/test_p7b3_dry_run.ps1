# ============================================================
# OSA / ISA — P7B3 DRY RUN TEST
# ============================================================

$ErrorActionPreference = "Stop"

$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB = "osa_db"
$USER = "postgres"

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7B3" -ForegroundColor Red
        exit 1
    }
}

Write-Host "========================================="
Write-Host " OSA — P7B3 DRY RUN TEST"
Write-Host "========================================="

Test-Sql "SELECT COUNT(*) AS nb_operational_policy_rows FROM rf.semantic_operational_policy;"
Test-Sql "SELECT COUNT(*) AS nb_operational_indicators FROM ma.v_semantic_operational_policy_engine;"
Test-Sql "SELECT semantic_operational_status, COUNT(*) AS nb FROM ma.v_semantic_operational_policy_engine GROUP BY semantic_operational_status ORDER BY nb DESC;"
Test-Sql "SELECT isa_operational_decision, COUNT(*) AS nb FROM ma.v_semantic_operational_policy_engine GROUP BY isa_operational_decision ORDER BY nb DESC;"
Test-Sql "SELECT l2_imputation_decision, COUNT(*) AS nb FROM ma.v_semantic_operational_policy_engine GROUP BY l2_imputation_decision ORDER BY nb DESC;"
Test-Sql "SELECT ml_operational_decision, COUNT(*) AS nb FROM ma.v_semantic_operational_policy_engine GROUP BY ml_operational_decision ORDER BY nb DESC;"
Test-Sql "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(semantic_operational_score),3) AS avg_operational_score FROM ma.v_semantic_operational_policy_engine GROUP BY pillar_code ORDER BY avg_operational_score;"
Test-Sql "SELECT COUNT(*) AS no_imputation_cert_required FROM ma.v_semantic_operational_policy_engine WHERE l2_imputation_decision = 'NO_IMPUTATION_CERTIFICATION_REQUIRED';"
Test-Sql "SELECT COUNT(*) AS ml_forecast_disabled FROM ma.v_semantic_operational_policy_engine WHERE ml_operational_decision = 'ML_FORECAST_DISABLED';"

Write-Host ""
Write-Host "✅ P7B3 dry-run terminé avec succès" -ForegroundColor Green
