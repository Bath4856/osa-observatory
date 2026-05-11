$ErrorActionPreference = "Stop"

Write-Host "========================================="
Write-Host " OSA — P7B6 DRY RUN TEST"
Write-Host "========================================="

$Psql = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
if (-not (Test-Path $Psql)) { $Psql = "psql" }

$DbHost = "127.0.0.1"
$DbUser = "postgres"
$DbName = "osa_db"

function Test-Sql($sql) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $Psql -h $DbHost -U $DbUser -d $DbName -v ON_ERROR_STOP=1 -c $sql
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7B6" -ForegroundColor Red
        exit 1
    }
}

Test-Sql "SELECT CASE WHEN to_regclass('rf.semantic_weighting_policy') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_policy, CASE WHEN to_regclass('ma.v_semantic_strategic_weighting_engine') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_engine, CASE WHEN to_regclass('ma.v_isa_dynamic_weighting_readiness') IS NOT NULL THEN 'OK' ELSE 'MISSING' END AS check_readiness;"

Test-Sql "SELECT COUNT(*) AS nb_weighting_policy_rows FROM rf.semantic_weighting_policy;"

Test-Sql "SELECT COUNT(*) AS nb_weighted_indicators FROM ma.v_semantic_strategic_weighting_engine;"

Test-Sql "SELECT strategic_weighting_class, COUNT(*) AS nb FROM ma.v_semantic_strategic_weighting_engine GROUP BY strategic_weighting_class ORDER BY nb DESC;"

Test-Sql "SELECT isa_weighting_decision, COUNT(*) AS nb FROM ma.v_semantic_strategic_weighting_engine GROUP BY isa_weighting_decision ORDER BY nb DESC;"

Test-Sql "SELECT ml_weighting_decision, COUNT(*) AS nb FROM ma.v_semantic_strategic_weighting_engine GROUP BY ml_weighting_decision ORDER BY nb DESC;"

Test-Sql "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(isa_dynamic_weight),3) AS avg_isa_weight, ROUND(AVG(systemic_vulnerability_weight),3) AS avg_vulnerability_weight FROM ma.v_semantic_strategic_weighting_engine GROUP BY pillar_code ORDER BY avg_isa_weight DESC;"

Test-Sql "SELECT COUNT(*) AS readiness_rows FROM ma.v_isa_dynamic_weighting_readiness;"

Test-Sql "SELECT COUNT(*) AS locked_gap_weights FROM ma.v_semantic_strategic_weighting_engine WHERE strategic_weighting_class = 'WEIGHT_LOCKED_GAP';"

Write-Host ""
Write-Host "✅ P7B6 dry-run terminé avec succès" -ForegroundColor Green
