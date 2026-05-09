$PSQL = "C:\Program Files\PostgreSQL\17\bin\psql.exe"
$DB   = "osa_db"
$USER = "postgres"

Write-Host "========================================="
Write-Host " OSA — P7A3 DRY RUN TEST"
Write-Host "========================================="

$queries = @(
  "SELECT COUNT(*) AS nb_semantic_indicators FROM ma.v_signal_semantic_engine_v3;",
  "SELECT semantic_governance_status, COUNT(*) AS nb FROM ma.v_signal_semantic_engine_v3 GROUP BY semantic_governance_status ORDER BY nb DESC;",
  "SELECT COUNT(*) AS critical_review_remaining FROM ma.v_signal_semantic_engine_v3 WHERE semantic_governance_status='CRITICAL_SEMANTIC_REVIEW';",
  "SELECT semantic_code, COUNT(*) AS nb FROM ma.v_signal_semantic_engine_v3 GROUP BY semantic_code ORDER BY nb DESC;",
  "SELECT * FROM ma.v_semantic_priority_engine ORDER BY pillar_code, semantic_code LIMIT 30;"
)

foreach ($q in $queries) {
    Write-Host ""
    Write-Host ">>> Test SQL"
    & $PSQL -U $USER -d $DB -v ON_ERROR_STOP=1 -c $q
    if ($LASTEXITCODE -ne 0) {
        Write-Host "❌ Erreur dry-run P7A3" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "✅ P7A3 dry-run terminé avec succès" -ForegroundColor Green
