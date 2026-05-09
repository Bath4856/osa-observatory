$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"
$ROOT = "G:\osa-observatory"

Write-Host "========================================="
Write-Host " OSA — P6 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
    "SELECT COUNT(*) AS nb_swot_vectors FROM ma.v_swot_vectors;",
    "SELECT COUNT(*) AS nb_ai_ml_vectors FROM ma.v_ai_ml_sovereignty_vector;",
    "SELECT * FROM ma.v_swot_vectors LIMIT 5;",
    "SELECT * FROM ma.v_ai_ml_sovereignty_vector LIMIT 5;",
    "SELECT pillar_code, COUNT(*) AS nb, ROUND(AVG(ai_ml_readiness_score),3) AS avg_readiness FROM ma.v_ai_ml_sovereignty_vector GROUP BY pillar_code ORDER BY avg_readiness;"
)

foreach ($q in $queries) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q

    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run"
        exit 1
    }
}

Write-Host ""
Write-Host ">>> Test rapport P6"
& $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -f "$ROOT\audit\p6_trust_vulnerability_report.sql"

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Erreur rapport P6"
    exit 1
}

Write-Host ""
Write-Host "✅ P6 dry-run terminé avec succès"